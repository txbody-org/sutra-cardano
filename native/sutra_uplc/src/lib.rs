use uplc::tx::{eval_phase_two_raw};
use rustler::{Encoder, Env, NifResult, Term, Binary, OwnedBinary};

fn convert_to_binary<'a>(env: Env<'a>, bytes: Vec<u8>) -> Binary<'a> {
    let mut binary = OwnedBinary::new(bytes.len()).unwrap();
    binary.as_mut_slice().copy_from_slice(&bytes);
    binary.release(env)
}

#[rustler::nif]
fn eval_phase_two<'a>(
    env: Env<'a>,
    tx_bytes: Binary<'a>,
    utxos: Vec<(Binary<'a>, Binary<'a>)>,
    cost_models_bytes: Option<Binary<'a>>,
    initial_budget: (u64, u64),
    slot_config: (u64, u64, u32)
) -> NifResult<Term<'a>> {
    // Convert Binary to Vec<u8> to extend lifetime
    let tx_vec = tx_bytes.as_slice().to_vec();
    
    // Convert Vec<(Binary, Binary)> to Vec<(Vec<u8>, Vec<u8>)>
    let utxos_converted: Vec<(Vec<u8>, Vec<u8>)> = utxos
        .into_iter()
        .map(|(key, value)| (
            key.as_slice().to_vec(),
            value.as_slice().to_vec()
        ))
        .collect();
    
    // Convert Optional Binary to Vec<u8>
    let cost_models_vec = cost_models_bytes
        .map(|b| b.as_slice().to_vec());
    
    // Get cost models slice reference
    let cost_models_slice = cost_models_vec
        .as_ref()
        .map(|v| v.as_slice());


    // Call the evaluation function
    match eval_phase_two_raw(
        &tx_vec,
        &utxos_converted,
        cost_models_slice,
        initial_budget,
        slot_config,
        true, // run_phase_one
        |_| ()
    ) {
        Ok(results) => {
            let term_results: Vec<Binary> = results
                .into_iter()
                .map(|bytes| convert_to_binary(env, bytes))
                .collect();
            Ok((true, term_results).encode(env))
        }
        Err(e) => Ok((false, e.to_string()).encode(env))
    }
}

rustler::init!("Elixir.Sutra.Uplc");