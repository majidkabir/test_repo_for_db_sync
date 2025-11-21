SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


Create View [dbo].[V_StorerConfig2] 
as Select storerconfig.storerkey, storerconfig.ConfigKey,  Max(Svalue) as Svalue
FROM dbo.storerconfig storerconfig with (NOLOCK)
group by storerconfig.storerkey, storerconfig.ConfigKey



GO