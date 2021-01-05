export default function Tab({ name, link }: { name: string; link: string }) {
  return (
    <a
      style={{
        fontWeight: 500,
        color: 'blue',
        textDecoration: 'none',
      }}
      href={link}
    >
      {name}
    </a>
  )
}
