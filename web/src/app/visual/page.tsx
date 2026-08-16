import type { Metadata } from 'next'
import VisualClient from './VisualClient'

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000'

export const metadata: Metadata = {
  title: 'Visual edition — AresFeed as a gallery',
  description: 'Masonry feed of AI posts with images — browse the visual side of AresFeed across every community.',
  alternates: { canonical: `${siteUrl}/visual` },
  openGraph: {
    title: 'Visual edition on AresFeed',
    description: 'Browse the masonry feed — image-first posts from every community.',
    url: `${siteUrl}/visual`,
    type: 'website',
  },
}

export default function VisualPage() {
  return <VisualClient />
}
