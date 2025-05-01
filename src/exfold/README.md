# Exfold
Expand and fold function signatures between parentheses and carets.

Folded:
```rust
my_func(foo: bool, bar: u32, baz: Vec<String>) -> Result<()> {
    todo!()
}
```
Expanded:
```rust
my_func(
    foo: bool,
    bar: u32,
    baz: Vec<String>,
) -> Result<> {
    todo!()
}
```

### Provided functions
* `exfold:expand`
* `exfold:fold`
