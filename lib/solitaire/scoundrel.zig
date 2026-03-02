const std = @import("std");
const card_mod = @import("card.zig");
const Card = card_mod.Card;
const Deck = card_mod.Deck;

pub const Phase = enum {
    room, // Interacting with cards in the field
    escape, // Option to deal a new room
    game_over,
};

pub const ScoundrelState = struct {
    allocator: std.mem.Allocator,
    rng: std.Random,
    deck: Deck,
    field: [4]?Card,
    active_card: ?Card, // Current weapon
    monster_stack: Deck, // Monsters defeated by current weapon (must be descending)
    removed_pile: Deck,
    health: i32,
    max_health: i32,
    last_action_escaped: bool = false,
    potion_consumed_in_room: bool = false,
    cards_interacted_in_room: usize = 0,
    is_won: bool = false,
    is_lost: bool = false,

    pub fn init(allocator: std.mem.Allocator, rng: std.Random) !ScoundrelState {
        var deck = Deck.init(allocator, rng);

        // Standard 52-card deck with J,Q,K,A of hearts and diamonds removed
        for (std.enums.values(card_mod.Suit)) |suit| {
            for (std.enums.values(card_mod.Rank)) |rank| {
                if (rank == .joker) continue;

                // Remove J, Q, K, A of hearts and diamonds
                if (suit == .hearts or suit == .diamonds) {
                    switch (rank) {
                        .jack, .queen, .king, .ace => continue,
                        else => {},
                    }
                }

                try deck.append(.{ .suit = suit, .rank = rank });
            }
        }
        deck.shuffle();

        var state = ScoundrelState{
            .allocator = allocator,
            .rng = rng,
            .deck = deck,
            .field = .{ null, null, null, null },
            .active_card = null,
            .monster_stack = Deck.init(allocator, rng),
            .removed_pile = Deck.init(allocator, rng),
            .health = 20,
            .max_health = 20,
        };

        try state.dealRoom();
        return state;
    }

    pub fn deinit(self: *ScoundrelState) void {
        self.deck.deinit();
        self.monster_stack.deinit();
        self.removed_pile.deinit();
    }

    pub fn dealRoom(self: *ScoundrelState) !void {
        // In Scoundrel, the 4th card stays in the room if it wasn't used.
        // We only deal cards to empty slots.
        // Note: escape() already handles clearing the field to the bottom of the deck.

        // Deal cards to fill empty slots back up to 4
        for (&self.field) |*slot| {
            if (slot.* == null) {
                slot.* = self.deck.draw();
            }
        }
        self.cards_interacted_in_room = 0;
        self.potion_consumed_in_room = false;
    }

    pub fn escape(self: *ScoundrelState) !bool {
        if (self.last_action_escaped) return false;
        if (self.deck.count() == 0) return false;

        // Move field to bottom of deck
        for (&self.field) |*slot| {
            if (slot.*) |c| {
                try self.deck.putOnBottom(c);
                slot.* = null;
            }
        }

        self.last_action_escaped = true;
        try self.dealRoom();
        return true;
    }

    pub fn canAdvanceRoom(self: ScoundrelState) bool {
        // Player can advance if they've used 3 cards, or if the field is empty (rare case)
        if (self.cards_interacted_in_room >= 3) return true;

        var field_empty = true;
        for (self.field) |slot| if (slot != null) {
            field_empty = false;
            break;
        };
        return field_empty;
    }

    pub fn canUseWeapon(self: ScoundrelState, monster_val: i32) bool {
        if (self.active_card == null) return false;
        
        // If stack is empty, any monster can be fought with the weapon (it will deal Monster - Weapon damage)
        if (self.monster_stack.count() == 0) return true;

        const last_monster_val = @as(i32, self.monster_stack.cards[self.monster_stack.len - 1].rank.value());
        return monster_val < last_monster_val;
    }

    pub fn useCard(self: *ScoundrelState, field_idx: usize, use_weapon: bool) !void {
        if (field_idx >= 4) return error.InvalidIndex;
        if (self.field[field_idx] == null) return error.EmptySlot;
        if (self.cards_interacted_in_room >= 3) return error.RoomComplete;

        const card = self.field[field_idx].?;

        switch (card.suit) {
            .hearts => try self.consumePotion(field_idx),
            .diamonds => try self.equipWeapon(field_idx),
            .spades, .clubs => try self.fightMonster(field_idx, use_weapon),
        }

        self.cards_interacted_in_room += 1;
        self.last_action_escaped = false; // Must face at least one card before escaping again
        self.checkGameState();
    }

    fn consumePotion(self: *ScoundrelState, idx: usize) !void {
        const card = self.field[idx].?;
        if (!self.potion_consumed_in_room) {
            const heal_amt = card.rank.value();
            self.health = @min(self.max_health, self.health + @as(i32, heal_amt));
            self.potion_consumed_in_room = true;
        }
        try self.removed_pile.append(card);
        self.field[idx] = null;
    }

    fn equipWeapon(self: *ScoundrelState, idx: usize) !void {
        const card = self.field[idx].?;
        if (self.active_card) |old_weapon| {
            try self.removed_pile.append(old_weapon);
            // Also remove all monsters in the stack associated with old weapon
            while (self.monster_stack.draw()) |m| {
                try self.removed_pile.append(m);
            }
        }
        self.active_card = card;
        self.field[idx] = null;
    }

    fn fightMonster(self: *ScoundrelState, idx: usize, use_weapon: bool) !void {
        const card = self.field[idx].?;
        const monster_val = @as(i32, card.rank.value());

        if (use_weapon) {
            if (!self.canUseWeapon(monster_val)) return error.WeaponConstraintViolation;

            const weapon_val = @as(i32, self.active_card.?.rank.value());
            // Damage is reduced by weapon value
            const damage = @max(0, monster_val - weapon_val);
            self.health -= damage;
            try self.monster_stack.append(card);
        } else {
            // Unarmed combat (either by choice or forced) - full damage taken
            self.health -= monster_val;
            try self.removed_pile.append(card);
        }

        self.field[idx] = null;
    }

    fn checkGameState(self: *ScoundrelState) void {
        if (self.health <= 0) {
            self.is_lost = true;
            return;
        }

        var field_empty = true;
        for (self.field) |slot| if (slot != null) {
            field_empty = false;
            break;
        };

        if (field_empty and self.deck.count() == 0) {
            self.is_won = true;
        }
    }
};
