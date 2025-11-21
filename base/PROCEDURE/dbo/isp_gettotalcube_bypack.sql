SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetTotalCube_ByPack                            */
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
 
CREATE PROCEDURE [dbo].[isp_GetTotalCube_ByPack] 
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

   DECLARE @cCartonType NVARCHAR( 10)
   DECLARE @nCarton     INT
   DECLARE @nCartonCube FLOAT
   DECLARE @cStorerKey  NVARCHAR( 15)
   
   SET @nTotalCube = 0

   IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
   BEGIN
      SELECT TOP 1 @cStorerKey = StorerKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      DECLARE curCartonType CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PF.CartonType, COUNT( DISTINCT PD.CartonNo)
         FROM PackHeader PH WITH (NOLOCK)
            INNER JOIN PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            LEFT OUTER JOIN PackInfo PF WITH (NOLOCK) ON (PD.PickSlipNo = PF.PickSlipNo AND PD.CartonNo = PF.CartonNo)
         WHERE PH.OrderKey = @cOrderKey
         GROUP BY PF.CartonType
   END
   ELSE IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
   BEGIN
      SELECT TOP 1 @cStorerKey = StorerKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      DECLARE curCartonType CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PF.CartonType, COUNT( DISTINCT PD.CartonNo)
         FROM PackHeader PH WITH (NOLOCK)
            INNER JOIN PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            LEFT OUTER JOIN PackInfo PF WITH (NOLOCK) ON (PD.PickSlipNo = PF.PickSlipNo AND PD.CartonNo = PF.CartonNo)
         WHERE PH.PickSlipNo = @cPickSlipNo
         GROUP BY PF.CartonType
   END

   OPEN curCartonType
   FETCH NEXT FROM curCartonType INTO @cCartonType, @nCarton
   WHILE @@FETCH_STATUS = 0  
   BEGIN
      SET @nCartonCube = 0
      IF @cCartonType IS NULL
         SELECT @nCartonCube = C.Cube
         FROM Cartonization C WITH (NOLOCK)
            INNER JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.UseSequence = 1
      ELSE
         SELECT @nCartonCube = C.Cube
         FROM Cartonization C WITH (NOLOCK)
            INNER JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.CartonType = @cCartonType

      SET @nTotalCube = @nTotalCube + (@nCarton * @nCartonCube)
      FETCH NEXT FROM curCartonType INTO @cCartonType, @nCarton
   END
   CLOSE curCartonType
   DEALLOCATE curCartonType

GO