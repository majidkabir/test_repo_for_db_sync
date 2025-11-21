SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CheckDropID_05                                  */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Check validity of Drop ID scanned (SOS#302191)              */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-Nov-2014 1.0  ChewKP      Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_CheckDropID_05] (
   @cFacility                 NVARCHAR( 5),
   @cStorerKey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cDropID                   NVARCHAR( 18),
   @nValid                    INT          OUTPUT, 
   @nErrNo                    INT          OUTPUT, 
   @cErrMsg     				 NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success INT
   DECLARE @n_err		 INT
   DECLARE @c_errmsg  NVARCHAR( 250)
         , @cWaveKey  NVARCHAR(10) 
         
   SET @cWaveKey = ''
   
   
   SELECT @cWaveKey = V_String1
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND UserName = suser_sname()
   AND Func = '1620'
   
   IF ISNULL(@cWaveKey , '' ) <> '' 
   BEGIN
      IF SUBSTRING(@cDropID, 1, 2) + SUBSTRING(@cDropID, 3, 10) <> 
         'ID' + @cWaveKey
         SET @nValid = 0
      ELSE
         SET @nValid = 1
   END
   ELSE
   BEGIN
      IF SUBSTRING(@cDropID, 1, 2) + SUBSTRING(@cDropID, 3, 10) <> 
         'ID' + @cOrderKey
         SET @nValid = 0
      ELSE
         SET @nValid = 1
   END
END

GO