SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW  [BI].[V_JReportAPInodes] AS
SELECT OutputURL = n.NSQLDescrip + s.OPTION5 + '/' + c.NSQLDescrip + '/' + j.SecondLvl + '/' + j.FolderPath
   ,j.*
   ,n.[ConfigKey]
   ,n.[NSQLValue]
   ,n.[NSQLDefault]
   ,n.[NSQLDescrip]
   ,AddDateN   =n.[AddDate]
   ,AddWhoN    =n.[AddWho]
   ,EditDateN  =n.[EditDate]
   ,EditWhoN   =n.[EditWho]
   ,ConfigKeyC =c.[ConfigKey]
   ,ISO2Code   =c.[NSQLValue]
   ,ISO3Code   =c.[NSQLDefault]
   ,CountryName=c.[NSQLDescrip]
   ,AddDateC   =c.[AddDate]
   ,AddWhoC    =c.[AddWho]
   ,EditDateC  =c.[EditDate]
   ,EditWhoC   =c.[EditWho]
FROM NSQLCONFIG n WITH (NOLOCK)
LEFT JOIN StorerConfig s WITH (NOLOCK) ON s.ConfigKey='GetJReportURL' AND s.Facility='' AND StorerKey='ALL'
LEFT JOIN NSQLCONFIG c WITH (NOLOCK) ON c.ConfigKey='JReportCountry'
LEFT JOIN JReportFolder j WITH (NOLOCK) ON 1=1
WHERE n.ConfigKey='JReportURL'

GO