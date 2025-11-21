SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DPPickslipNo01                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get Pick Slip No thru customized stored proc                */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2008-05-15 1.0  jwong    Create                                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_DPPickslipNo01] (
   @c_WaveKey       NVARCHAR( 10),
   @c_OrderKey      NVARCHAR( 10),
   @c_PickDetailKey NVARCHAR( 10) = '',
   @c_PickHeaderKey NVARCHAR( 10) OUTPUT
) AS 

BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT @c_PickHeaderKey = PH.PickHeaderKey
   FROM dbo.WaveDetail WD WITH (NOLOCK)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (WD.OrderKey = LPD.OrderKey)
   JOIN dbo.PickHeader PH WITH (NOLOCK) ON (LPD.LoadKey = PH.ExternOrderKey)
   WHERE WD.WaveKey = @c_WaveKey
      AND WD.OrderKey = @c_OrderKey

   IF @@ROWCOUNT = 0 SET @c_PickHeaderKey = ''
   
END

GO