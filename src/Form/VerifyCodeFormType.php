<?php

namespace App\Form;

use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\Extension\Core\Type\TextType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolver;
use Symfony\Component\Validator\Constraints as Assert;

class VerifyCodeFormType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder
            ->add('code', TextType::class, [
                'label' => 'Code de verification',
                'attr' => [
                    'maxlength' => 6,
                    'pattern' => '[0-9]{6}',
                    'autocomplete' => 'one-time-code',
                    'inputmode' => 'numeric',
                    'class' => 'text-center text-2xl tracking-[0.5em] font-mono',
                    'placeholder' => '000000',
                ],
                'constraints' => [
                    new Assert\NotBlank(message: 'Veuillez entrer le code.'),
                    new Assert\Length(exactly: 6, exactMessage: 'Le code doit faire 6 chiffres.'),
                    new Assert\Regex(pattern: '/^\d{6}$/', message: 'Le code doit contenir uniquement des chiffres.'),
                ],
            ]);
    }

    public function configureOptions(OptionsResolver $resolver): void
    {
        $resolver->setDefaults([]);
    }
}
