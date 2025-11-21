SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetTotalStdGrossWgt_ByPackInfo                 */
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
/* 12-Sep-2013  Chee          Initial Version.                          */
/* 01-Apr-2015  NJOW01        333179-Get pickslip from pickheader       */
/************************************************************************/
 
CREATE PROCEDURE [dbo].[isp_GetTotalStdGrossWgt_ByPackInfo] 
   @cPickSlipNo  NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10),  
   @nTotalWeight FLOAT OUTPUT, 
   @nCurrentTotalWeight FLOAT = NULL
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nTotalWeight = 0

   --NJOW01
   IF ISNULL(@cPickSlipNo, '') = '' 
      SELECT TOP 1 @cPickSlipNo = PH.PickheaderKey 
      FROM PickHeader PH WITH (NOLOCK)
      WHERE PH.OrderKey = @cOrderKey

   IF ISNULL(@cPickSlipNo, '') = '' 
      SELECT TOP 1 @cPickSlipNo = PD.PickSlipno
      FROM PickDetail PD WITH (NOLOCK)
      WHERE PD.OrderKey = @cOrderKey

   IF EXISTS(SELECT 1 FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)      
      SELECT @nTotalWeight = SUM(ISNULL(PACKINFO.Weight,0))     
      FROM   PACKINFO WITH (NOLOCK)      
      WHERE  PickSlipNo = @cPickSlipNo
 
   -- If no packinfo, get weight from SKU
   IF @nTotalWeight = 0 
      SELECT @nTotalWeight = ISNULL( SUM( SKU.StdGrossWgt * PD.QTY), 0)
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PD.OrderKey = @cOrderKey
   
END -- Procedure

GO