SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CheckCaseID_01                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check validity of Case ID scanned (SOS204018)               */
/*          Case ID cannot be same as 1st 10 char of SKU                */
/*                                                                      */
/* Called from: rdtfnc_Case_Pick                                        */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-Feb-2011 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_CheckCaseID_01] (
   @cStorerKey                NVARCHAR( 15),
   @cSKU                      NVARCHAR( 20),
   @cCaseID                   NVARCHAR( 10),
   @nValid                    INT          OUTPUT, 
   @nErrNo                    INT          OUTPUT, 
   @cErrMsg     				 NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_success INT
   DECLARE @n_err		 INT
   DECLARE @c_errmsg  NVARCHAR( 250)

   IF SUBSTRING(LTRIM(RTRIM(@cCaseID)), 1, 10) = SUBSTRING(LTRIM(RTRIM(@cSKU)), 1, 10) 
      SET @nValid = 0
   ELSE
      SET @nValid = 1
END

GO