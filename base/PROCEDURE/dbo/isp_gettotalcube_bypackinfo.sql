SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetTotalCube_ByPackInfo                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 12-Dec-2013  Chee          Initial Version.                          */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_GetTotalCube_ByPackInfo]
   @cPickSlipNo NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @nTotalCube  FLOAT OUTPUT,
   @nCurrentTotalCube FLOAT = NULL,
   @nCtnCnt1 INT = NULL,
   @nCtnCnt2 INT = NULL,
   @nCtnCnt3 INT = NULL,
   @nCtnCnt4 INT = NULL,
   @nCtnCnt5 INT = NULL
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nTotalCube = 0

   IF ISNULL(@cPickSlipNo, '') = ''
      SELECT TOP 1 @cPickSlipNo = PH.PickheaderKey
      FROM PickHeader PH WITH (NOLOCK)
      WHERE PH.OrderKey = @cOrderKey

   IF ISNULL(@cPickSlipNo, '') = ''
      SELECT TOP 1 @cPickSlipNo = PD.PickSlipno
      FROM PickDetail PD WITH (NOLOCK)
      WHERE PD.OrderKey = @cOrderKey

   IF EXISTS(SELECT 1 FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      SELECT @nTotalCube = SUM(ISNULL(PACKINFO.Cube,0))
      FROM   PACKINFO WITH (NOLOCK)
      WHERE  PickSlipNo = @cPickSlipNo

   -- If no packinfo, get cube from SKU
   IF @nTotalCube = 0
      SELECT @nTotalCube = ISNULL( SUM( SKU.StdCube * PD.QTY), 0)
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PD.OrderKey = @cOrderKey

END -- Procedure

GO