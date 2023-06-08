package card

// Defines the various components of a card on the client side

CardID      :: distinct u8
AbilityID   :: distinct u8
Cards       :: [256]Card

// Corresponding to Core.Fields of the game instance
Field :: enum u8 {
    Revealed,               // Flags
    Zone, Phase,            // Enums
    SetID, CardNum, Owner,  // U8
}

Card :: struct {
    id : CardID,    // 0 denotes that the card is hidden and is NOT the card id
    fieldMap : map[Field]u8,
    abilities : [dynamic]AbilityID,
}
