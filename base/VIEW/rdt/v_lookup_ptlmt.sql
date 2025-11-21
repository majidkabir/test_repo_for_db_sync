SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose:                                                                   */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2013-07-18 1.0  ChewKP     Created                                         */
/******************************************************************************/
CREATE   VIEW [RDT].[v_LookUp_PTLMT]
AS
   SELECT [Description] AS [Text],
       [Code] AS [Value]
   FROM   dbo.Codelkup WITH (NOLOCK)
   WHERE ListName = 'PTL_MT'



GO