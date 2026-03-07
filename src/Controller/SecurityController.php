<?php

namespace App\Controller;

use App\Entity\User;
use App\Form\ForgotPasswordFormType;
use App\Form\RegistrationFormType;
use App\Form\ResetPasswordFormType;
use App\Form\VerifyCodeFormType;
use App\Repository\UserRepository;
use App\Service\SecurityCodeService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\RateLimiter\RateLimiterFactory;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Authentication\AuthenticationUtils;

class SecurityController extends AbstractController
{
    #[Route('/login', name: 'app_login')]
    public function login(AuthenticationUtils $authenticationUtils): Response
    {
        if ($this->getUser()) {
            return $this->redirectToRoute('app_home');
        }

        return $this->render('security/login.html.twig', [
            'last_username' => $authenticationUtils->getLastUsername(),
            'error' => $authenticationUtils->getLastAuthenticationError(),
        ]);
    }

    #[Route('/logout', name: 'app_logout')]
    public function logout(): never
    {
        throw new \LogicException('This method can be blank - it will be intercepted by the logout key on your firewall.');
    }

    #[Route('/register', name: 'app_register')]
    public function register(
        Request $request,
        UserPasswordHasherInterface $passwordHasher,
        EntityManagerInterface $em,
        SecurityCodeService $codeService,
        RateLimiterFactory $registerLimiter,
    ): Response {
        if ($this->getUser()) {
            return $this->redirectToRoute('app_home');
        }

        $form = $this->createForm(RegistrationFormType::class);
        $form->handleRequest($request);

        $limiter = $registerLimiter->create($request->getClientIp());
        if ($form->isSubmitted() && !$limiter->consume()->isAccepted()) {
            $this->addFlash('error', 'Trop de tentatives d\'inscription. Reessayez dans une heure.');
            return $this->render('security/register.html.twig', [
                'form' => $form,
            ]);
        }

        if ($form->isSubmitted() && $form->isValid()) {
            $user = new User();
            $user->setEmail($form->get('email')->getData());
            $user->setPassword(
                $passwordHasher->hashPassword($user, $form->get('plainPassword')->getData())
            );

            $em->persist($user);
            $em->flush();

            $code = $codeService->generateCode($user);
            $codeService->sendVerificationEmail($user, $code);

            $request->getSession()->set('verify_user_id', $user->getId());

            $this->addFlash('success', 'Un code de verification a ete envoye a votre adresse email.');
            return $this->redirectToRoute('app_verify');
        }

        return $this->render('security/register.html.twig', [
            'form' => $form,
        ]);
    }

    #[Route('/verify', name: 'app_verify')]
    public function verify(
        Request $request,
        UserRepository $userRepository,
        SecurityCodeService $codeService,
    ): Response {
        $userId = $request->getSession()->get('verify_user_id');
        if (!$userId) {
            return $this->redirectToRoute('app_register');
        }

        $user = $userRepository->find($userId);
        if (!$user || $user->isVerified()) {
            $request->getSession()->remove('verify_user_id');
            return $this->redirectToRoute('app_login');
        }

        $form = $this->createForm(VerifyCodeFormType::class);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            if ($codeService->verifyCode($user, $form->get('code')->getData())) {
                $request->getSession()->remove('verify_user_id');
                $this->addFlash('success', 'Votre compte a ete verifie ! Vous pouvez vous connecter.');
                return $this->redirectToRoute('app_login');
            }

            $this->addFlash('error', 'Code invalide ou expire.');
        }

        return $this->render('security/verify.html.twig', [
            'form' => $form,
            'email' => $user->getEmail(),
        ]);
    }

    #[Route('/verify/resend', name: 'app_verify_resend')]
    public function resendCode(
        Request $request,
        UserRepository $userRepository,
        SecurityCodeService $codeService,
    ): Response {
        $userId = $request->getSession()->get('verify_user_id');
        if (!$userId) {
            return $this->redirectToRoute('app_register');
        }

        $user = $userRepository->find($userId);
        if (!$user || $user->isVerified()) {
            return $this->redirectToRoute('app_login');
        }

        $code = $codeService->generateCode($user);
        $codeService->sendVerificationEmail($user, $code);

        $this->addFlash('success', 'Un nouveau code a ete envoye.');
        return $this->redirectToRoute('app_verify');
    }

    #[Route('/forgot-password', name: 'app_forgot_password')]
    public function forgotPassword(
        Request $request,
        UserRepository $userRepository,
        SecurityCodeService $codeService,
    ): Response {
        $form = $this->createForm(ForgotPasswordFormType::class);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            $user = $userRepository->findOneBy(['email' => $form->get('email')->getData()]);

            if ($user) {
                $token = $codeService->generateResetToken($user);
                $codeService->sendResetPasswordEmail($user, $token);
            }

            // Always show success to prevent email enumeration
            $this->addFlash('success', 'Si un compte existe avec cet email, un lien de reinitialisation a ete envoye.');
            return $this->redirectToRoute('app_login');
        }

        return $this->render('security/forgot_password.html.twig', [
            'form' => $form,
        ]);
    }

    #[Route('/reset-password/{token}', name: 'app_reset_password')]
    public function resetPassword(
        string $token,
        Request $request,
        UserRepository $userRepository,
        UserPasswordHasherInterface $passwordHasher,
        EntityManagerInterface $em,
    ): Response {
        $user = $userRepository->findByResetToken($token);
        if (!$user) {
            $this->addFlash('error', 'Lien de reinitialisation invalide ou expire.');
            return $this->redirectToRoute('app_forgot_password');
        }

        $form = $this->createForm(ResetPasswordFormType::class);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            $user->setPassword(
                $passwordHasher->hashPassword($user, $form->get('plainPassword')->getData())
            );
            $user->setResetToken(null);
            $user->setResetTokenExpiresAt(null);
            $em->flush();

            $this->addFlash('success', 'Votre mot de passe a ete modifie. Vous pouvez vous connecter.');
            return $this->redirectToRoute('app_login');
        }

        return $this->render('security/reset_password.html.twig', [
            'form' => $form,
        ]);
    }
}
