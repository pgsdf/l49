# Debugging Milestone 1

## Expected output
p9cons: run
p9root: run
p9probe: begin
L49 milestone1
hello from p9probe

## Common causes
- Scenario not selected
- root_ep cap name mismatch
- Server not replying due to wrong receive primitive
- Transport magic mismatch
- Rerror returned due to unknown fid or not found walk

## Rule
Log request type and tag on both sides.
If Rerror is received, decode the string and print it.
