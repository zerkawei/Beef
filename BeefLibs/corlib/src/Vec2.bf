namespace System;

public struct Vec2 : vec2
{
	public static Self operator+(Self lhs, Self rhs)
	{
		return (SelfBase)lhs + (SelfBase)rhs;
	}
}