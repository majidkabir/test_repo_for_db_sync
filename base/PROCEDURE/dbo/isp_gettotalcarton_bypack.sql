SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetTotalCarton_ByPack                          */
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
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 25-May-2011  Ung           SOS216105 Configurable SP to calc         */
/*                            carton, cube and weight                   */
/************************************************************************/
 
CREATE PROCEDURE [dbo].[isp_GetTotalCarton_ByPack] 
   @cPickSlipNo  NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10),  
   @cCtnTyp1     NVARCHAR( 10) OUTPUT, 
   @cCtnTyp2     NVARCHAR( 10) OUTPUT, 
   @cCtnTyp3     NVARCHAR( 10) OUTPUT, 
   @cCtnTyp4     NVARCHAR( 10) OUTPUT, 
   @cCtnTyp5     NVARCHAR( 10) OUTPUT, 
   @nCtnCnt1     INT OUTPUT, 
   @nCtnCnt2     INT OUTPUT, 
   @nCtnCnt3     INT OUTPUT, 
   @nCtnCnt4     INT OUTPUT, 
   @nCtnCnt5     INT OUTPUT
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cDefaultCtnTyp NVARCHAR( 10)

   SET @cCtnTyp1 = ''
   SET @cCtnTyp2 = ''
   SET @cCtnTyp3 = ''
   SET @cCtnTyp4 = ''
   SET @cCtnTyp5 = ''
   SET @nCtnCnt1 = 0
   SET @nCtnCnt2 = 0
   SET @nCtnCnt3 = 0
   SET @nCtnCnt4 = 0
   SET @nCtnCnt5 = 0

   IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
   BEGIN
      SELECT @cStorerKey = StorerKey FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      
      SELECT @nCtnCnt1 = COUNT( DISTINCT PD.LabelNo)
      FROM PackHeader PH WITH (NOLOCK)
         INNER JOIN PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE PH.OrderKey = @cOrderKey
   END
   
   IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
   BEGIN
      SELECT @cStorerKey = StorerKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

      SELECT @nCtnCnt1 = COUNT( DISTINCT PD.LabelNo)
      FROM PackHeader PH WITH (NOLOCK)
         INNER JOIN PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE PH.PickSlipNo = @cPickSlipNo
   END
      
   -- Get default carton type
   SET @cDefaultCtnTyp = ''
   SELECT @cDefaultCtnTyp = C.CartonType
   FROM CARTONIZATION C WITH (NOLOCK)
      INNER JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
   WHERE S.StorerKey = @cStorerKey
      AND UseSequence = 1
   IF @cDefaultCtnTyp = '' 
      SET @cDefaultCtnTyp = 'CARTON'

   IF @nCtnCnt1 > 0
      SET @cCtnTyp1 = @cDefaultCtnTyp

GO