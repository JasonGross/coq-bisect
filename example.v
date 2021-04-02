Set Universe Polymorphism.
Axiom admit : forall {T}, T.
Axiom IsGlob@{u} : forall (n : nat) (A : Type@{u}), Type@{u+1}.
Fixpoint F {n : nat} {A : Type} {H : IsGlob n A} {struct n} : nat
with G {n : nat} {A} {H : IsGlob n A} {struct n} : nat.
Proof.
  1: pose (G n A).
  all: exact admit.
Defined.
