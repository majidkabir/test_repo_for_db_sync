SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW V_Wrapup_Validation AS
SELECT  SC.Listname
      , [Config]        = SC.Code
      , [ConfigDescr]   = SC.Description
      , SC.Storerkey
      , [Facility]      = SC.Code2
      , [Role]          = CL.ListName
      , [RoleNo]        = CL.Code
      , [RoleDescr]     = CL.Description
      , [RoleType]      = CL.Short
      , [RoleCatagory]  = CL.Long
      , [RoleSQL1]      = CL.Notes
      , [RoleSQL2]      = CL.Notes2 
FROM CODELKUP CL WITH (NOLOCK)
JOIN CODELKUP SC WITH (NOLOCK) ON (SC.ListName = 'VALDNCFG')
                               AND(SC.UDF01 = CL.ListName)

GO