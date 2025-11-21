SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetTotalCarton_ByPick3                         */
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
 
CREATE PROCEDURE [dbo].[isp_GetTotalCarton_ByPick3]
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
   DECLARE @cType          NVARCHAR( 1)
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

   -- Determine Xdock, conso or discrete
   IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
   BEGIN
      -- Get pickheader info
      DECLARE @cLoadKey NVARCHAR( 20)
      DECLARE @cZone    NVARCHAR( 18)
      SELECT TOP 1
         @cLoadKey = ExternOrderkey, 
         @cOrderKey = OrderKey, 
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo
      
      IF @cType IN ('XD', 'LB', 'LP')
         SET @cType = 'X' -- XDock
      ELSE 
         IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
            SET @cType = 'D' -- Discrete
         ELSE
            SET @cType = 'C' -- Conso
   END
   ELSE
      IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
         SET @cType = 'D' -- Discrete 

   -- Discrete
   IF @cType = 'D'
   BEGIN
      SELECT TOP 1 @cStorerKey = StorerKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      SELECT @nCtnCnt1 = ISNULL( SUM( PD.QTY / Pack.CaseCnt), 0)
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Pack WITH (NOLOCK) ON PD.PackKey = Pack.PackKey
         INNER JOIN dbo.LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
      WHERE PD.OrderKey = @cOrderKey
         AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) = 0
         AND LOC.LocationType <> 'PICK' 

      SELECT @nCtnCnt2 = COUNT( DISTINCT PD.SKU)
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Pack WITH (NOLOCK) ON PD.PackKey = Pack.PackKey
         INNER JOIN dbo.LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
      WHERE PD.OrderKey = @cOrderKey
         AND PD.QTY > 0
         AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) > 0
         AND LOC.LocationType = 'PICK' 
   END

   -- Conso
   IF @cType = 'C'
   BEGIN
      SELECT TOP 1 @cStorerKey = StorerKey FROM OrderDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey

      SELECT @nCtnCnt1 = ISNULL( SUM( PD.QTY / Pack.CaseCnt), 0)
      FROM dbo.OrderDetail OD WITH (NOLOCK)
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = OD.PackKey
         INNER JOIN dbo.LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
      WHERE OD.LoadKey = @cLoadKey
         AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) = 0
         AND LOC.LocationType <> 'PICK' 
         
      SELECT @nCtnCnt2 = COUNT( DISTINCT PD.SKU)
      FROM dbo.OrderDetail OD WITH (NOLOCK)
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = OD.PackKey
         INNER JOIN dbo.LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
      WHERE OD.LoadKey = @cLoadKey
         AND PD.QTY > 0
         AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) > 0
         AND LOC.LocationType = 'PICK' 
   END

   -- XDock
   IF @cType = 'X'
   BEGIN
      SELECT TOP 1 @cStorerKey = PD.StorerKey
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
      WHERE RKL.PickSlipNo = @cPickSlipNo

      SELECT @nCtnCnt1 = ISNULL( SUM( PD.QTY / Pack.CaseCnt), 0)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
         INNER JOIN dbo.Pack WITH (NOLOCK) ON PD.PackKey = Pack.PackKey
         INNER JOIN dbo.LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
      WHERE RKL.PickSlipNo = @cPickSlipNo
         AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) = 0
         AND LOC.LocationType <> 'PICK' 

      SELECT @nCtnCnt2 = COUNT( DISTINCT PD.SKU)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON PD.PackKey = Pack.PackKey
         INNER JOIN dbo.LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
      WHERE RKL.PickSlipNo = @cPickSlipNo
         AND PD.QTY > 0
         AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) > 0
         AND LOC.LocationType = 'PICK' 
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

   SET @cCtnTyp1 = @cDefaultCtnTyp
   SET @cCtnTyp2 = @cDefaultCtnTyp

GO