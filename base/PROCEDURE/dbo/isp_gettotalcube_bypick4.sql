SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetTotalCube_ByPick4                           */
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
 
CREATE PROCEDURE [dbo].[isp_GetTotalCube_ByPick4] 
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
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey NVARCHAR( 15)
   DECLARE @nCube1 FLOAT
   DECLARE @nCube2 FLOAT
   DECLARE @nCube3 FLOAT
   DECLARE @nCube4 FLOAT
   DECLARE @nCube5 FLOAT
      
   SET @nCube1 = 0 
   SET @nCube2 = 0 
   SET @nCube3 = 0 
   SET @nCube4 = 0 
   SET @nCube5 = 0 
   SET @nTotalCube = 0

   IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
   BEGIN
      SELECT TOP 1 @cStorerKey = StorerKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      SELECT 
         @nCtnCnt1 = MD.CtnCnt1, 
         @nCtnCnt2 = MD.CtnCnt2, 
         @nCtnCnt3 = MD.CtnCnt3, 
         @nCtnCnt4 = MD.CtnCnt4, 
         @nCtnCnt5 = MD.CtnCnt5  
      FROM MBOLDetail MD WITH (NOLOCK)
      WHERE MD.OrderKey = @cOrderKey
   END

   IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
   BEGIN
      DECLARE @cLoadKey NVARCHAR( 10)
      SELECT @cLoadKey = ExternOrderkey FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo
      
      SELECT TOP 1 @cStorerKey = StorerKey 
      FROM LoadPlanDetail LPD WITH (NOLOCK) 
         INNER JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey 
      
      SELECT 
         @nCtnCnt1 = LP.CtnCnt1, 
         @nCtnCnt2 = LP.CtnCnt2, 
         @nCtnCnt3 = LP.CtnCnt3, 
         @nCtnCnt4 = LP.CtnCnt4, 
         @nCtnCnt5 = LP.CtnCnt5  
      FROM LoadPlan LP WITH (NOLOCK)
      WHERE LP.LoadKey = @cLoadKey
   END

   SELECT 
      @nCube1 = CASE WHEN UseSequence = 1 THEN C.Cube ELSE @nCube1 END, 
      @nCube2 = CASE WHEN UseSequence = 2 THEN C.Cube ELSE @nCube2 END, 
      @nCube3 = CASE WHEN UseSequence = 3 THEN C.Cube ELSE @nCube3 END, 
      @nCube4 = CASE WHEN UseSequence = 4 THEN C.Cube ELSE @nCube4 END, 
      @nCube5 = CASE WHEN UseSequence = 5 THEN C.Cube ELSE @nCube5 END 
   FROM Cartonization C WITH (NOLOCK)
      INNER JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
   WHERE S.StorerKey = @cStorerKey
   
   SET @nTotalCube = 
      (@nCtnCnt1 * @nCube1) + 
      (@nCtnCnt2 * @nCube2) + 
      (@nCtnCnt3 * @nCube3) + 
      (@nCtnCnt4 * @nCube4) + 
      (@nCtnCnt5 * @nCube5)

GO