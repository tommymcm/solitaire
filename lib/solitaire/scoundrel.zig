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
    cards_interacted_in_room: usize = 0,
    is_won: bool = false,
    is_lost: bool = false,

    pub fn init(allocator: std.mem.Allocator, rng: std.Random) !ScoundrelState {
        var deck = Deck.init(allocator, rng);

        // Standard 52-card deck
        for (std.enums.values(card_mod.Suit)) |suit| {
            for (std.enums.values(card_mod.Rank)) |rank| {
                if (rank == .joker) continue;
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
        // Move remaining field cards to removed if we didn't escape
        if (!self.last_action_escaped) {
            for (&self.field) |*slot| {
                if (slot.*) |c| {
                    try self.removed_pile.append(c);
                    slot.* = null;
                }
            }
        }

        // Deal 4 cards
        for (0..4) |i| {
            self.field[i] = self.deck.draw();
        }
        self.cards_interacted_in_room = 0;
        self.last_action_escaped = false;
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

    pub fn useCard(self: *ScoundrelState, field_idx: usize) !void {
        if (field_idx >= 4) return error.InvalidIndex;
        const card = self.field[field_idx] orelse return error.EmptySlot;

        switch (card.suit) {
            .hearts => try self.consumePotion(field_idx),
            .spades => try self.equipWeapon(field_idx),
            .diamonds, .clubs => try self.fightMonster(field_idx),
        }

        self.cards_interacted_in_room += 1;
        self.checkGameState();
    }

    fn consumePotion(self: *ScoundrelState, idx: usize) !void {
        const card = self.field[idx].?;
        const heal_amt = card.rank.value();
        self.health = @min(self.max_health, self.health + @as(i32, heal_amt));
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

    fn fightMonster(self: *ScoundrelState, idx: usize) !void {
        const card = self.field[idx].?;
        const monster_val = @as(i32, card.rank.value());

        if (self.active_card) |weapon| {
            const weapon_val = @as(i32, weapon.rank.value());
            const last_monster_val = if (self.monster_stack.count() > 0)
                @as(i32, self.monster_stack.cards[self.monster_stack.len - 1].rank.value())
            else
                weapon_val;

            if (monster_val < last_monster_val) {
                // Defeated with weapon
                try self.monster_stack.append(card);
            } else {
                // Take damage even with weapon if monster is too strong
                self.health -= monster_val;
                try self.removed_pile.append(card);
            }
        } else {
            // Unarmed combat - full damage
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
