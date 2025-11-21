SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* View: V_ViewReportPrintType                                             */
/* Creation Date: 2020-09-11                                               */
/* Copyright: LF Logistics                                                 */
/* Written by: Wan                                                         */
/*                                                                         */
/* Purpose: LFWM-2321 - [KR] UAT_View Report module, No add report function*/
/*                                                                         */
/* Called By: SCE                                                          */
/*          :                                                              */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 8.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 2020-11-19  Wan01    1.0   Created                                      */
/***************************************************************************/
CREATE VIEW [dbo].[V_ViewReportPrintType]
AS 
SELECT  CODELKUP.ListName
      , CODELKUP.Code
      , CODELKUP.[Description]
      , CODELKUP.Short
      , CODELKUP.Long
      , CODELKUP.Storerkey
      , CODELKUP.Code2
      , CODELKUP.Notes
      , CODELKUP.Notes2
      , CODELKUP.UDF01
      , CODELKUP.UDF02
      , CODELKUP.UDF03
      , CODELKUP.UDF04
      , CODELKUP.UDF05
FROM CODELKUP WITH (NOLOCK) 
WHERE CODELKUP.LISTNAME = 'WMPrintTyp'
AND   CODELKUP.Long = 'DataWindow'

GO