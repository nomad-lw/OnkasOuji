from eth_hash.auto import keccak
import sys

def simulate_dice_roll(current_random_hex, round_number):
    # Make sure current_random_hex starts with '0x'
    if not current_random_hex.startswith('0x'):
        current_random_hex = '0x' + current_random_hex

    # Convert round number to 32 bytes, padded from left
    round_hex = hex(round_number)[2:].zfill(64)

    # Remove '0x' prefix for concatenation
    current_random_bytes = bytes.fromhex(current_random_hex[2:])
    round_bytes = bytes.fromhex(round_hex)

    # Concatenate and hash
    packed = current_random_bytes + round_bytes
    new_random = keccak(packed)

    # Convert to integer and calculate dice roll exactly as Solidity does
    random_int = int.from_bytes(new_random, 'big')
    dice_roll = (random_int % 6) + 1

    return dice_roll, '0x' + new_random.hex()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <current_random_hex> <round_number>")
        print("Example: python script.py 0x6f0a975977e8b685640b663af683567f09444f7c57da5f942c1dd38a7a1fb7a4 1")
        sys.exit(1)

    current_random = sys.argv[1]
    round_num = int(sys.argv[2])


    print("Round 1")
    roll, new_random = simulate_dice_roll(current_random, round_num)
    print(f"Dice Roll1: {roll}")
    print(f"New Random: {new_random}")
    roll2, new_random = simulate_dice_roll(new_random, round_num + 1)
    print(f"Dice Roll2: {roll2}")
    print(f"New Random: {new_random}")
    round_num += 1
    print("Round 2")
    roll, new_random = simulate_dice_roll(new_random, round_num)
    print(f"Dice Roll1: {roll}")
    print(f"New Random: {new_random}")
    roll2, new_random = simulate_dice_roll(new_random, round_num + 1)
    print(f"Dice Roll2: {roll2}")
    print(f"New Random: {new_random}")
    round_num += 1
    print("Round 3")
    roll, new_random = simulate_dice_roll(new_random, round_num)
    print(f"Dice Roll1: {roll}")
    print(f"New Random: {new_random}")
    roll2, new_random = simulate_dice_roll(new_random, round_num + 1)
    print(f"Dice Roll2: {roll2}")
    print(f"New Random: {new_random}")
    round_num += 1
    print("Round 4")
    roll, new_random = simulate_dice_roll(new_random, round_num)
    print(f"Dice Roll1: {roll}")
    print(f"New Random: {new_random}")
    roll2, new_random = simulate_dice_roll(new_random, round_num + 1)
    print(f"Dice Roll2: {roll2}")
    print(f"New Random: {new_random}")
    round_num += 1
    print("Round 5")
    roll, new_random = simulate_dice_roll(new_random, round_num)
    print(f"Dice Roll1: {roll}")
    print(f"New Random: {new_random}")
    roll2, new_random = simulate_dice_roll(new_random, round_num + 1)
    print(f"Dice Roll2: {roll2}")
    print(f"New Random: {new_random}")
