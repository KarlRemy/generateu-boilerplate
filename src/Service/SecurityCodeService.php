<?php

namespace App\Service;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Twig\Environment;

class SecurityCodeService
{
    public function __construct(
        private readonly EntityManagerInterface $em,
        private readonly MailerInterface $mailer,
        private readonly Environment $twig,
        private readonly string $adminEmail = 'noreply@example.com',
    ) {
    }

    public function generateCode(User $user): string
    {
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $user->setVerificationCode($code);
        $user->setVerificationCodeExpiresAt(new \DateTimeImmutable('+15 minutes'));
        $this->em->flush();

        return $code;
    }

    public function verifyCode(User $user, string $code): bool
    {
        if ($user->getVerificationCode() === null) {
            return false;
        }

        if ($user->getVerificationCodeExpiresAt() < new \DateTimeImmutable()) {
            return false;
        }

        if (!hash_equals($user->getVerificationCode(), $code)) {
            return false;
        }

        $user->setIsVerified(true);
        $user->setVerificationCode(null);
        $user->setVerificationCodeExpiresAt(null);
        $this->em->flush();

        return true;
    }

    public function sendVerificationEmail(User $user, string $code): void
    {
        $html = $this->twig->render('emails/verification_code.html.twig', [
            'user' => $user,
            'code' => $code,
        ]);

        $email = (new Email())
            ->from($this->adminEmail)
            ->to($user->getEmail())
            ->subject('Votre code de verification')
            ->html($html);

        $this->mailer->send($email);
    }

    public function generateResetToken(User $user): string
    {
        $token = bin2hex(random_bytes(32));
        $user->setResetToken($token);
        $user->setResetTokenExpiresAt(new \DateTimeImmutable('+1 hour'));
        $this->em->flush();

        return $token;
    }

    public function sendResetPasswordEmail(User $user, string $token): void
    {
        $html = $this->twig->render('emails/reset_password.html.twig', [
            'user' => $user,
            'token' => $token,
        ]);

        $email = (new Email())
            ->from($this->adminEmail)
            ->to($user->getEmail())
            ->subject('Reinitialisation de votre mot de passe')
            ->html($html);

        $this->mailer->send($email);
    }
}
