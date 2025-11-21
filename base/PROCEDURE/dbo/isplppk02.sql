SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispLPPK02                                          */
/* Creation Date: 11-Nov-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#195492                                                  */
/*                                                                      */
/* Called By: Load Plan                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 18-Feb-2011  NJOW01   1.0  206246-Fix StdCube cannot fit big carton  */
/*                            type.                                     */
/* 24-Mar-2014  TLTING   1.1  SQL2012 Bug                               */
/* 07-Apr-2014  Audrey   1.1  SOS308047 - Bug fixed.                    */
/************************************************************************/

CREATE PROC [dbo].[ispLPPK02]
   @cLoadKey    NVARCHAR(10),
   @bSuccess    INT      OUTPUT,
   @nErr        INT      OUTPUT,
   @cErrMsg     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickSlipNo         NVARCHAR(10),
           @cOrderKey           NVARCHAR(10),
           @cStorerKey          NVARCHAR(15),
           @cSku                NVARCHAR(20),
           @cComponentSku       NVARCHAR(20),
           @nComponentQty       INT,
           @nQty                INT,
           @nContinue           INT,
           @nStartTCnt          INT,
           @cCartonGroup        NVARCHAR(10),
           @nStdCube            DECIMAL(18,4),
           @nOrderCube          DECIMAL(18,4),
           @nCartonCube         DECIMAL(18,4),
           @nSkuCube            DECIMAL(18,4),
           @cCartonizationGroup NVARCHAR(10),
           @cCartonType         NVARCHAR(10),
           @cLabelNo            NVARCHAR(20),
           @nPackQty            INT,
           @cLabelGenCode       NVARCHAR(10)

   CREATE TABLE #TMP_PICKSKU
      (StorerKey  NVARCHAR(15) NULL,
      Sku         NVARCHAR(20) NULL,
      CartonGroup NVARCHAR(10) NULL,
      Qty         INT NULL,
      StdCube     DECIMAL(18,4) NULL)

   SELECT @nContinue = 1, @nStartTCnt = @@TRANCOUNT, @nErr = 0, @cErrMsg = ''

   IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK)
             JOIN  ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
             WHERE PD.Status='4' AND PD.Qty > 0
              AND  O.LoadKey = @cLoadKey)
   BEGIN
      SELECT @nContinue = 3
      SELECT @nErr = 39000
      SELECT @cErrmsg='NSQL'+CONVERT(VARCHAR(5), @nErr)+': Found Short Pick with Qty > 0 '
      GOTO QUIT_SP
   END

   BEGIN TRAN

   DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey
     FROM LoadPlanDetail (NOLOCK)
    WHERE LoadKey = @cLoadKey

   OPEN CUR_ORDER
   FETCH NEXT FROM CUR_ORDER INTO @cOrderKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @cPickSlipNo = ''
      SELECT @cPickSlipNo = PickHeaderKey
      FROM PickHeader (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Create PickHeader
      IF ISNULL(@cPickSlipNo ,'') = ''
      BEGIN
         EXECUTE dbo.nspg_GetKey
                 'PICKSLIP', 9, @cPickSlipNo OUTPUT, @bSuccess OUTPUT, @nErr OUTPUT, @cErrmsg OUTPUT

         SELECT @cPickSlipNo = 'P' + @cPickSlipNo

         INSERT INTO PickHeader
                     (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)
              VALUES (@cPickSlipNo , @cLoadKey, @cOrderKey, '0', 'D', '')
      END

      IF (SELECT COUNT(1) FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) = 0
      BEGIN
         INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
         VALUES (@cPickSlipNo, GETDATE(), SUSER_SNAME(), NULL)
      END

      UPDATE PickDetail WITH (ROWLOCK)
         SET PickSlipNo = @cPickSlipNo
           , TrafficCop = NULL
       WHERE OrderKey = @cOrderKey

      -- Create packheader if not exists
      IF (SELECT COUNT(1) FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) = 0
      BEGIN
         INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, LoadKey, Consigneekey, StorerKey, PickSlipNo)
         SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo
           FROM PickHeader PH (NOLOCK)
           JOIN Orders O (NOLOCK) ON (PH.Orderkey = O.Orderkey)
          WHERE PH.PickHeaderKey = @cPickSlipNo
      END
      ELSE
      BEGIN
         IF (SELECT COUNT(1) FROM PackDetail (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) > 0
            GOTO SKIP_ORDER
      END

      DELETE FROM #TMP_PICKSKU

      INSERT INTO #TMP_PICKSKU (Storerkey, Sku, CartonGroup, Qty, StdCube)
      SELECT PD.StorerKey, PD.Sku, PD.CartonGroup, SUM(PD.Qty), CONVERT(DECIMAL(18,4),S.StdCube) AS StdCube
      FROM PickDetail PD (NOLOCK)
      JOIN Sku S (NOLOCK) ON (PD.Storerkey = S.Storerkey AND PD.Sku = S.Sku)
      WHERE PD.OrderKey = @cOrderKey
      AND PD.Qty > 0
      AND PD.CartonGroup <> 'PREPACK'
      GROUP BY PD.StorerKey, PD.Sku, PD.CartonGroup, S.StdCube
      UNION ALL
      SELECT PD.StorerKey, PD.AltSku, PD.CartonGroup, CASE WHEN SUM(B.Qty) > 0 THEN SUM(PD.Qty) / SUM(B.Qty) ELSE SUM(PD.Qty) END AS Qty,
             CONVERT(DECIMAL(18,4),S.StdCube) AS StdCube
      FROM PickDetail PD (NOLOCK)
      JOIN BillOfMaterial B (NOLOCK) ON (PD.Storerkey = B.Storerkey AND PD.AltSku = B.Sku)
      JOIN Sku S (NOLOCK) ON (PD.Storerkey = S.Storerkey AND PD.AltSku = S.Sku)
      WHERE PD.OrderKey = @cOrderKey
      AND PD.Qty > 0
      AND PD.CartonGroup = 'PREPACK'
      GROUP BY PD.StorerKey, PD.AltSku, PD.CartonGroup, S.StdCube

      SELECT @nOrderCube = SUM(Qty * StdCube)
      FROM #TMP_PICKSKU

      SET @nSkuCube = 0
      SET @nCartonCube = 0

      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT StorerKey, Sku, CartonGroup, Qty, StdCube
         FROM #TMP_PICKSKU (NOLOCK)
         ORDER BY Sku

      OPEN CUR_PICKDETAIL

      FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSku, @cCartonGroup, @nQty, @nStdCube
      WHILE @@FETCH_STATUS<>-1
      BEGIN
         SET @nSkuCube = @nStdCube * @nQty
         WHILE  @nSkuCube > 0
         BEGIN
            IF ISNULL(@nCartonCube,0) <= 0
            BEGIN
               SELECT TOP 1 @nCartonCube = CONVERT(DECIMAL(18,4),CZ.[Cube]), @cCartonType = CZ.Cartontype
               FROM Cartonization CZ (NOLOCK)
               JOIN Storer S (NOLOCK) ON (CZ.CartonizationGroup = S.CartonGroup)
               WHERE S.Storerkey = @cStorerkey
               AND CZ.[Cube] >= @nOrderCube
               ORDER BY CZ.[Cube]

               IF ISNULL(@nCartonCube,0) <= 0
               BEGIN
                  SELECT TOP 1 @nCartonCube = CONVERT(DECIMAL(18,4),CZ.[Cube]), @cCartonType = CZ.Cartontype
                  FROM Cartonization CZ (NOLOCK)
                  JOIN Storer S (NOLOCK) ON (CZ.CartonizationGroup = S.CartonGroup)
                  WHERE S.Storerkey = @cStorerkey
                  ORDER BY CZ.[Cube] DESC
               END

               IF ISNULL(@nCartonCube,0) <= 0
               BEGIN
                  SELECT @nContinue = 3
                  SELECT @nErr = 38000
                  SELECT @cErrMsg = 'Cartonization Cube Not Yet Setup For ' + RTRIM(@cStorerkey)
                  GOTO QUIT_SP
               END

               IF ISNULL(@nCartonCube,0) < @nStdCube --NJOW01
               BEGIN
                  SELECT @nContinue = 3
                  SELECT @nErr = 38010
                  SELECT @cErrMsg = 'Sku '+ RTRIM(@cSku)+' StdCude Cannot Fit In Carton Type '+ RTRIM(@cCartonType)
                  GOTO QUIT_SP
               END

               -- New Carton Label
               SELECT @cLabelGenCode = SValue
               FROM StorerConfig (NOLOCK)
               WHERE Storerkey = @cStorerkey
               AND Configkey = 'CartonLabelNoGenCode'

               IF ISNULL(@cLabelGenCode,'') IN ('','0')
               BEGIN
                  SELECT @nContinue = 3
                  SELECT @nErr = 38001
                  SELECT @cErrMsg = 'Storerconfig CartonLabelNoGenCode Not Yet Assign SP Name To Generate Label# (' + RTRIM(@cStorerkey) + ')'
                  GOTO QUIT_SP
               END

               EXEC isp_Exec_LabelGenCode
                    @cLabelGenCode,
                    @cPickSlipNo,
                    0,
                    @cLabelNo OUTPUT,
                    @nErr     OUTPUT,
                    @cErrMsg  OUTPUT

               IF @nErr <> 0
               BEGIN
                  SELECT @nContinue = 3
                  GOTO QUIT_SP
               END

               IF ISNULL(@cLabelNo,'') = ''
               BEGIN
                  SELECT @nContinue = 3
                  SELECT @nErr = 38002
                  SELECT @cErrMsg = 'Label# is empty generated from Storerconfig CartonLabelNoGenCode With SP Name ' + RTRIM(@cLabelGenCode)
                  GOTO QUIT_SP
               END
            END

            SET @nPackQty = 0
            WHILE @nCartonCube > 0 AND @nSkuCube > 0
            BEGIN
               IF @nCartonCube < @nStdCube
               BEGIN
                  SET @nCartonCube = 0
                  CONTINUE
               END
               SET @nSkuCube    = @nSkuCube - @nStdCube
               SET @nCartonCube = @nCartonCube - @nStdCube
               SET @nOrderCube  = @nOrderCube - @nStdCube
               SET @nQty        = @nQty - 1
               SET @nPackQty    = @nPackQty + 1

            END

            IF @cCartonGroup = 'PREPACK'
            BEGIN
               -- CartonNo and LabelLineNo will be inserted by trigger
               DECLARE CUR_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ComponentSku, Qty
                  FROM BillOfMaterial (NOLOCK)
                  WHERE Storerkey = @cStorerkey
                  AND Sku = @cSku
                  ORDER BY ComponentSku

               OPEN CUR_BOM

               FETCH NEXT FROM CUR_BOM INTO @cComponentSku, @nComponentQty
               WHILE @@FETCH_STATUS<>-1
               BEGIN
                  IF ( ISNULL(@nPackQty, 0) * ISNULL(@nComponentQty, 0) ) > 0 -- SOS308047
                  BEGIN
                     INSERT INTO PackDetail
                        (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, AddWho, AddDate, EditWho, EditDate, Refno2)
                     VALUES
                        (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cComponentSku,
                         @nPackQty * @nComponentQty, SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE(), @cCartonType)

                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @nContinue = 3
                        SELECT @nErr = 38003
                        SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert PackDetail Table (ispLPPK02)'
                        GOTO QUIT_SP
                     END
                  END

                  FETCH NEXT FROM CUR_BOM INTO @cComponentSku, @nComponentQty
               END
               CLOSE CUR_BOM
               DEALLOCATE CUR_BOM
            END
            ELSE
            BEGIN
               IF ISNULL(@nPackQty, 0) > 0 -- SOS308047
               BEGIN
                  -- CartonNo and LabelLineNo will be inserted by trigger
                  INSERT INTO PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, AddWho, AddDate, EditWho, EditDate, Refno2)
                  VALUES
                     (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku,
                      @nPackQty, SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE(), @cCartonType)

                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @nContinue = 3
                     SELECT @nErr = 38004
                     SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert PackDetail Table (ispLPPK02)'
                     GOTO QUIT_SP
                  END
               END
            END
         END

         FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSku, @cCartonGroup, @nQty, @nStdCube
      END
      CLOSE CUR_PICKDETAIL
      DEALLOCATE CUR_PICKDETAIL

      DELETE FROM PackInfo WHERE PickSlipNo = @cPickSlipNo

      INSERT INTO PackInfo (PickSlipNo, CartonNo, [Cube], CartonType, Weight)
      SELECT PD.PickSlipNo, PD.CartonNo, CZ.[Cube], CZ.CartonType, SUM(PD.Qty * Sku.StdGrossWgt)
      FROM PackDetail PD (NOLOCK)
      JOIN Storer S (NOLOCK) ON (PD.Storerkey = S.Storerkey)
      JOIN Cartonization CZ (NOLOCK) ON (S.CartonGroup = CZ.CartonizationGroup AND PD.RefNo2 = CZ.CartonType)
      JOIN Sku (NOLOCK) ON (PD.Storerkey = PD.Storerkey AND PD.Sku = Sku.Sku)
      WHERE PD.PickSlipNo = @cPickSlipNo
      GROUP BY PD.PickSlipNo, PD.CartonNo, CZ.[Cube], CZ.CartonType

      SKIP_ORDER:

      FETCH NEXT FROM CUR_ORDER INTO @cOrderKey
   END
   CLOSE CUR_ORDER
   DEALLOCATE CUR_ORDER

   QUIT_SP:

   IF @nContinue = 3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @bSuccess = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @nStartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @nStartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_LogError @nErr, @cErrmsg, 'ispLPPK02'
      RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @bSuccess = 1
      WHILE @@TRANCOUNT > @nStartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO