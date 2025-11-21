SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CheckDropID_03                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check duplicate Drop ID scanned (SOSxxxxx)                  */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 03-Aug-2012 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_CheckDropID_03] (
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
   
   DECLARE @cPickSlipNo NVARCHAR( 10)
   
   SELECT TOP 1 @cPickSlipNo = PickHeaderKey
   FROM dbo.PickHeader WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey

   IF ISNULL(@cPickSlipNo, '') = ''
   BEGIN
      SET @nValid = 0
      GOTO Quit
   END
      
   -- Check if dropid appear in different pickslip (Only work for discrete PS).
   IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND DropID = @cDropID
              AND PickSlipNo <> @cPickSlipNo)
      SET @nValid = 0
   ELSE
      SET @nValid = 1
      
   Quit:
END

GO