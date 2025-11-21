SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispIsWMS                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Check if app name = 'EXceed WMS'                            */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*  5-Sep-2012  KHLim         include EXceed 6.0 (KH01)                 */
/************************************************************************/

CREATE PROC [dbo].[ispIsWMS] (
   @nIsWMS INT OUTPUT
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   IF UPPER( APP_NAME()) = 'EXceed WMS' OR UPPER( APP_NAME()) = 'EXceed 6.0'  --KH01
      SET @nIsWMS = 1
   ELSE
      SET @nIsWMS = 0

   RETURN @nIsWMS
END

GO