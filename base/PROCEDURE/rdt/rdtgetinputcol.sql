SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtGetInputCol                                     */
/* Creation Date: 19-Dec-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Is a Recursive SP that was calling by rdtScr2XML to         */
/*          retrieve the value for the column number.                   */
/*                                                                      */
/* Input Parameters: Mobile No                                          */
/*                   Column Number (1 to 15)                            */
/*                                                                      */
/* Output Parameters: Column Value                                      */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/*                                                                      */
/* Called By: rdtScr2XML                                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*                                                                      */
/*                                                                      */
/************************************************************************/
CREATE PROC [RDT].[rdtGetInputCol]( 
   @nMobile INT, 
   @nColNo INT, 
   @cColValue NVARCHAR(60) OUTPUT
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE @cSQL NVARCHAR(4000)

   SELECT @cSQL =  N' SELECT @cValue = I_Field' + RIGHT('0' + RTRIM( CAST( @nColNo AS NVARCHAR( 2))), 2) +
                    ' FROM   RDT.RDTMOBREC (NOLOCK) ' +
                    ' WHERE  Mobile =' + CAST( @nMobile AS NVARCHAR( 5))

   EXEC sp_executesql @cSQL, N'@cValue NVARCHAR(60) output', @cColValue OUTPUT

GO