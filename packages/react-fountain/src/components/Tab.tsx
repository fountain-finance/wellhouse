export default function Tab({ name, link }: { name: string; link: string }) {
  return (
    <a href={link}>
      <div className="tab">{name}</div>
    </a>
  )
}
