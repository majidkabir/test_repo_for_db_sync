SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_ADIDAS_shortship_run (SHORT-SHIP ADIDAS)        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validate common UCC data error                              */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-07-12 1.0  UngDH    Created                                     */
/* 2014-02-06 1.1  Ung      SOS296465 Move QTYAlloc with UCC.Status=3   */
/* COMMENT NOTES   SY02                                                 */
/************************************************************************/

CREATE  PROCEDURE [dbo].[isp_ADIDAS_shortship_run] (
   @nOrderkey_input    NVARCHAR( 10)
  ,@nErrMsg            NVARCHAR(250) = ''  OUTPUT
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF


DECLARE
    @nIsDone INT = 0,
    @nPickQty INT = 0,
    @nPackQty INT = 0,
    @nDiffQty INT = 0,
    @nCartonNo INT = 0,
    @b_Success INT = 0,
    @cPickSlipNo NVARCHAR(10),
    @cLabelNo NVARCHAR(20),
    @cLabelLine NVARCHAR(5),
    @cNewLabelLine NVARCHAR(5),
    @cSKU NVARCHAR(20),
    @cPickDetailKey NVARCHAR(10),
    @c_PKD_PickDetailKey_New NVARCHAR(10),
    @c_ErrMsg NVARCHAR(250),
    @n_PickDetailQty INT, @n_PackDetailQty INT, @n_PickDetailCount INT,
    @n_AdjustQty INT, @n_AdjustQty_Balance INT, @n_PickDetailLineQty INT,
    @cOrderKey NVARCHAR(10) = @nOrderkey_input,
    @c_PickSlipNo NVARCHAR(10) = '',
    @c_D_SKU NVARCHAR(20), @c_PickDetailKey NVARCHAR(10),
    @PHCOUNT INT

SET @PHCOUNT = 0
SET @nErrMsg = ''
SELECT @PHCOUNT = COUNT(1) FROM AUWMS..PACKHEADER WITH (NOLOCK) WHERE
STORERKEY = 'ADIDAS' AND ORDERKEY = @nOrderkey_input

IF @PHCOUNT <> 1
BEGIN
    SET @nErrMsg = 'PACKHEADER NOT MATCH'
END
ELSE
BEGIN

    SELECT @c_PickSlipNo = PICKSLIPNO FROM AUWMS..PACKHEADER WITH (NOLOCK) WHERE
    STORERKEY = 'ADIDAS' AND ORDERKEY = @nOrderkey_input


         DECLARE C_PickDetailUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ISNULL(RTRIM(SKU),'')
               ,SUM(Qty)
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE PickSLipNo = @c_PickSlipNo
         GROUP BY ISNULL(RTRIM(SKU),'')

         OPEN C_PickDetailUpdate
         FETCH NEXT FROM C_PickDetailUpdate INTO @c_D_SKU
                                               , @n_PackDetailQty

         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SET @n_PickDetailQty = 0
            SELECT @n_PickDetailQty = SUM(Qty)
            FROM PICKDETAIL WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            AND SKU = @c_D_SKU

            IF @n_PackDetailQty < @n_PickDetailQty
            BEGIN
               IF @n_PickDetailCount = 1
               BEGIN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET Qty = @n_PackDetailQty
                     ,[Status] = '5'
                  WHERE OrderKey = @cOrderKey
                  AND SKU = @c_D_SKU

                  IF @@ERROR <> 0
                  BEGIN
                    ROLLBACK TRAN
                     --SET @n_Err = 68115
       --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                     --               + ': Fail to update PickDetail for ExternOrderKey = ' + @c_H_ExternOrderKey
                     --               + ' and LabelLine = ' + @c_LabelLine + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_WMSUPL)'
                     --GOTO PROCESS_UPDATE
                  END
               END
               ELSE
               BEGIN
                  SET @n_AdjustQty = @n_PackDetailQty - @n_PickDetailQty
                  SET @n_AdjustQty_Balance = @n_AdjustQty

                  DECLARE C_PickDetail_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT ISNULL(RTRIM(PickDetailKey),'')
                        ,Qty
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  AND SKU = @c_D_SKU
                  ORDER BY Qty DESC

                  OPEN C_PickDetail_LOOP
                  FETCH NEXT FROM C_PickDetail_LOOP INTO @c_PickDetailKey
                                                        ,@n_PickDetailLineQty

                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SET @n_AdjustQty_Balance = @n_PackDetailQty - @n_PickDetailLineQty
                     --SELECT @c_D_SKU '@c_D_SKU', @n_PackDetailQty '@n_PackDetailQty', @n_PickDetailLineQty '@n_PickDetailLineQty' --SY02
                     IF @n_AdjustQty_Balance <> 0
                     BEGIN
                        -- Still enough balance
                        IF @n_AdjustQty_Balance > 0
                        BEGIN
                           UPDATE PICKDETAIL WITH (ROWLOCK)
                           SET [Status] = '5'
                           WHERE PickDetailKey = @c_PickDetailKey

                           IF @@ERROR <> 0
                           BEGIN
                              ROLLBACK TRAN
                              --SET @n_Err = 68115
                              --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              --               + ': Fail to update PickDetail for ExternOrderKey = ' + @c_H_ExternOrderKey
                              --               + ' and LabelLine = ' + @c_LabelLine + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_WMSUPL)'
                              --GOTO PROCESS_UPDATE
                           END
                        END
                        -- Not enough balance, update whatever is in pack to pick
                        ELSE
                        BEGIN
                            --SELECT 'Pack less than pick', @c_D_SKU '@c_D_SKU', @n_PackDetailQty '@n_PackDetailQty', @n_PickDetailLineQty '@n_PickDetailLineQty'
                            -- If pack Qty is less than pick Qty
                            IF @n_PackDetailQty > 0 AND @n_PackDetailQty <= @n_PickDetailLineQty
                            BEGIN
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                              SET Qty = @n_PackDetailQty
                                 ,[Status] = '5'
                              WHERE PickDetailKey = @c_PickDetailKey
                            END
                            -- Unallocate the balance
                            ELSE
                            BEGIN
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                              SET Qty = 0
                                 ,[Status] = '5'
                              WHERE PickDetailKey = @c_PickDetailKey
                            END
                        END
                        --ELSE
                        --BEGIN
                        --   IF @n_PickDetailLineQty >= @n_AdjustQty_Balance
                        --   BEGIN
                        --      UPDATE PICKDETAIL WITH (ROWLOCK)
                        --      SET Qty = Qty + @n_AdjustQty_Balance
                        --        ,[Status] = '5'
                        --      WHERE PickDetailKey = @c_PickDetailKey

                        --      IF @@ERROR <> 0
                        --      BEGIN
                        --         ROLLBACK TRAN
                        --         --SET @n_Err = 68115
                        --         --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        --         --               + ': Fail to update PickDetail for ExternOrderKey = ' + @c_H_ExternOrderKey
                        --         --               + ' and LabelLine = ' + @c_LabelLine + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_WMSUPL)'
                        --         --GOTO PROCESS_UPDATE
                        --      END
                        --   END
                        --   ELSE
                        --   BEGIN
                        --      UPDATE PICKDETAIL WITH (ROWLOCK)
                        --      SET Qty = 0
                        --         ,[Status] = '5'
                        --      WHERE PickDetailKey = @c_PickDetailKey

                        --      IF @@ERROR <> 0
                        --      BEGIN
                        --         ROLLBACK TRAN
                        --        -- SET @n_Err = 68115
                        --        -- SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                        --        --                + ': Fail to update PickDetail for ExternOrderKey = ' + @c_H_ExternOrderKey
                        --        --                + ' and LabelLine = ' + @c_LabelLine + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_WMSUPL)'
                        --        --GOTO PROCESS_UPDATE
                        --      END

                        --      SET @n_AdjustQty_Balance = @n_AdjustQty_Balance - @n_PickDetailLineQty
                        --   END
                        --END
                     END
                     --SY01
                     IF @n_AdjustQty_Balance = 0
                     BEGIN
                        UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET [Status] = '5'
                        WHERE PickDetailKey = @c_PickDetailKey
                     END
                     --SY01

                     SET @n_PackDetailQty = @n_AdjustQty_Balance

                     FETCH NEXT FROM C_PickDetail_LOOP INTO @c_PickDetailKey
                                                           ,@n_PickDetailLineQty
                  END
                  CLOSE C_PickDetail_LOOP
                  DEALLOCATE C_PickDetail_LOOP
               END
            END
            ELSE IF @n_PackDetailQty = @n_PickDetailQty
            BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET [Status] = '5'
               WHERE OrderKey = @cOrderKey
               AND SKU = @c_D_SKU

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  --SET @n_Err = 68119
                  --SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                  --                  ': Fail to update PickDetail for ExternOrderKey = ' +
                  --                  @c_H_ExternOrderKey + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_WMSUPL)'
                  --GOTO NEXT_REC
               END
            END

            FETCH NEXT FROM C_PickDetailUpdate INTO @c_D_SKU
                                                  , @n_PackDetailQty
         END
         CLOSE C_PickDetailUpdate
         DEALLOCATE C_PickDetailUpdate

         -- Release the entirely not packed SKU
         DECLARE C_PickDetailStatusUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ISNULL(RTRIM(PickDetailKey),'')
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         --AND CaseID <> ''
         AND [Status] = 0

         OPEN C_PickDetailStatusUpdate
         FETCH NEXT FROM C_PickDetailStatusUpdate INTO @c_PickDetailKey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET Notes = 'Original Qty = ' + CAST(Qty AS NVARCHAR), Qty = 0, [Status] = '5'
            WHERE PickDetailKey = @c_PickDetailKey

            FETCH NEXT FROM C_PickDetailStatusUpdate INTO @c_PickDetailKey
         END
         CLOSE C_PickDetailStatusUpdate
         DEALLOCATE C_PickDetailStatusUpdate


  BEGIN
    SELECT OrderKey, SKU INTO #TempTable FROM PickDetail (NOLOCK)
    WHERE Status < '9'
    AND StorerKey = 'ADIDAS'
    AND DropID = ''
    AND QTY > 0
    AND OrderKey = @cOrderKey
    --AND SKU = 'DB3603-710'

    GROUP BY OrderKey, SKU
    ORDER BY OrderKey

    DECLARE CUR CURSOR FAST_FORWARD READ_ONLY FOR SELECT OrderKey, SKU FROM #TempTable
    OPEN CUR
    FETCH NEXT FROM CUR INTO @cOrderKey, @cSKU
    WHILE @@FETCH_STATUS <> -1
    BEGIN

    SET @cPickDetailKey = ''
    SET @cLabelNo = ''
    SET @cLabelLine = ''
    SET @nIsDone = 0
    SET @nCartonNo = 0

    WHILE @nIsDone = 0
    BEGIN
        SET @nDiffQty = 0
        SET @nCartonNo = 0

        SELECT TOP 1 @cPickDetailKey = PickDetailKey, @nPickQty = Qty FROM PickDetail (NOLOCK)
        WHERE OrderKey = @cOrderKey
        AND SKU = @cSKU
        AND QTY > 0
        AND PickDetailKey > @cPickDetailKey
        ORDER BY PickDetailKey

        IF @@ROWCOUNT = 0
        BEGIN
            SET @nIsDone = 1
            BREAK
        END

        --SELECT 'PD Candidate', * FROM PickDetail (NOLOCK)  --SY02
        --WHERE PickDetailKey = @cPickDetailKey    --SY02

        SELECT TOP 1
            @nCartonNo = CartonNo,
            @cPickSlipNo = PD.PickSlipNo,
            @cLabelNo = LabelNo,
            @cLabelLine = LabelLine,
            @nPackQty = Qty
        FROM PackDetail PD (NOLOCK)
        JOIN PackHeader PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
        WHERE OrderKey = @cOrderKey
        AND SKU = @cSKU
        AND PH.StorerKey = 'ADIDAS'
        AND LabelNo + LabelLine > @cLabeLNo + @cLabelLine
        --AND DropID = ''
        ORDER BY LabelNo, LabelLine

        IF @@ROWCOUNT = 0
        BEGIN
            SET @nIsDone = 1
            BREAK
        END

        -- EXPERIMENTAL (START)

        ---- Match by Qty first
        --SELECT TOP 1 @nCartonNo = CartonNo, @cPickSlipNo = PD.PickSlipNo, @cLabelNo = LabelNo, @cLabelLine = LabelLine, @nPackQty = Qty FROM PackDetail PD (NOLOCK)
        --JOIN PackHeader PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
        --WHERE OrderKey = @cOrderKey
        --AND SKU = @cSKU
        --AND PH.StorerKey = 'ADIDAS'
        --AND DropID = ''
        --AND Qty = @nPickQty
        --ORDER BY LabelNo, LabelLine

        ---- Match by LabelNo + LabelLine if no candidate is found
        --IF @@ROWCOUNT = 0
        --BEGIN
        --    SELECT TOP 1 @nCartonNo = CartonNo, @cPickSlipNo = PD.PickSlipNo, @cLabelNo = LabelNo, @cLabelLine = LabelLine, @nPackQty = Qty FROM PackDetail PD (NOLOCK)
        --    JOIN PackHeader PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
        --    WHERE OrderKey = @cOrderKey
        --    AND SKU = @cSKU
        --    AND PH.StorerKey = 'ADIDAS'
        --    AND LabelNo + LabelLine > @cLabeLNo + @cLabelLine
        --    AND DropID = ''
        --    ORDER BY LabelNo, LabelLine
        --END

        -- EXPERIMENTAL (END)

        --SELECT @cSKU '@cSKU', @cLabeLNo + @cLabelLine '@cLabeLNo + @cLabelLine', @nPickQty '@nPickQty', @nPackQty '@nPackQty'  --SY02

        IF @nPickQty < @nPackQty
        BEGIN
           SET @nDiffQty = @nPackQty - @nPickQty

           SELECT @cNewLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5) FROM PackDetail (NOLOCK)
           WHERE PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo

           INSERT PackDetail (
                PickSlipNo
              , CartonNo
              , LabelNo
              , LabelLine
              , StorerKey
              , SKU
              , Qty
              , AddWho
              , AddDate
              , EditWho
              , EditDate
              , RefNo
              , ArchiveCop
              , ExpQty
              , UPC
              , DropID
              , RefNo2
              , LOTTABLEVALUE
           )
           SELECT
                PickSlipNo
              , CartonNo
              , LabelNo
              , @cNewLabelLine
              , StorerKey
              , SKU
              , @nDiffQty
              , AddWho
              , AddDate
              , EditWho
              , EditDate
              , RefNo
              , '9'     -- Avoid trigger from assigning LabelNo, the script will handle it
              , ExpQty
              , UPC
              , DropID
              , RefNo2
              , LabelNo + '-' + LabelLine + ', split from ' + CAST(Qty AS NVARCHAR) + ' Qty to ' + CAST(@nDiffQty AS NVARCHAR) + ' Qty'
           FROM PackDetail (NOLOCK)
           WHERE PickSlipNo = @cPickSlipNo
           AND SKU = @cSKU
           AND LabelNo = @cLabeLNo
           AND LabelLine = @cLabelLine

           UPDATE PackDetail SET ArchiveCop = NULL     -- RESET ARCHIVECOP
           WHERE PickSlipNo = @cPickSlipNo
           AND SKU = @cSKU
           AND LabelNo = @cLabeLNo
           AND LabelLine = @cNewLabelLine

           --PRINT('Updating PackDetail in @nPickQty < @nPackQty...' + @cLabeLNo + ', ' + @cLabelLine)   --SY02

           UPDATE PackDetail SET Qty = @nPickQty, DropID = @cLabelNo, ArchiveCop = NULL     -- Reduce original Qty
           WHERE PickSlipNo = @cPickSlipNo
           AND SKU = @cSKU
           AND LabelNo = @cLabeLNo
           AND LabelLine = @cLabelLine

           UPDATE PickDetail SET CaseID = @cLabelNo, DropID = @cLabelNo, ArchiveCop = NULL
           WHERE PickDetailKey = @cPickDetailKey
        END
        ELSE IF @nPickQty > @nPackQty
        BEGIN
            SET @nDiffQty = @nPickQty - @nPackQty

            EXECUTE nspg_GetKey 'PICKDETAILKEY'
                ,10
                ,@c_PKD_PickDetailKey_New OUTPUT
                ,@b_Success               OUTPUT
                ,''
                ,@c_ErrMsg                OUTPUT

            --IF ISNULL(@c_ErrMsg, '') <> ''
            --BEGIN
            --    ROLLBACK TRAN
            --END

            INSERT PickDetail (
                PickDetailKey
              , CaseID
              , PickHeaderKey
              , OrderKey
              , OrderLineNumber
              , Lot
              , Storerkey
              , Sku
              , AltSku
              , UOM
              , UOMQty
              , Qty
              , QtyMoved
              , Status
              , DropID
              , Loc
              , ID
              , PackKey
              , UpdateSource
              , CartonGroup
              , CartonType
              , ToLoc
              , DoReplenish
              , ReplenishZone
              , DoCartonize
              , PickMethod
              , WaveKey
              , EffectiveDate
              , AddDate
              , AddWho
              , EditDate
              , EditWho
              , TrafficCop
              , ArchiveCop
              , OptimizeCop
              , ShipFlag
              , PickSlipNo
              , TaskDetailKey
              , TaskManagerReasonKey
              , Notes
              , MoveRefKey
              , Channel_ID
              , SourceType
            )
            SELECT
                @c_PKD_PickDetailKey_New
              , CaseID
              , PickHeaderKey
              , OrderKey
              , OrderLineNumber
              , Lot
              , Storerkey
              , Sku
              , AltSku
              , UOM
              , UOMQty
              , @nDiffQty
              , QtyMoved
              , Status
              , DropID
              , Loc
              , ID
              , PackKey
              , UpdateSource
              , CartonGroup
              , CartonType
              , ToLoc
              , DoReplenish
              , ReplenishZone
              , DoCartonize
              , PickMethod
              , WaveKey
              , EffectiveDate
              , AddDate
              , AddWho
              , EditDate
              , EditWho
              , TrafficCop
              , ArchiveCop
              , '1'
              , ShipFlag
              , PickSlipNo
              , TaskDetailKey
              , TaskManagerReasonKey
              , 'PickDetailKey = ' + PickDetailKey + ', split from ' + CAST(Qty AS NVARCHAR) + ' Qty to ' + CAST(@nDiffQty AS NVARCHAR) + ' Qty'
              , MoveRefKey
              , Channel_ID
              , SourceType
            FROM PickDetail (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey

            --PRINT('Updating PackDetail in @nPickQty > @nPackQty...' + @cLabeLNo + ', ' + @cLabelLine)   --SY02

            UPDATE PackDetail SET DropID = @cLabelNo, ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
            AND SKU = @cSKU
            AND LabelNo = @cLabeLNo
            AND LabelLine = @cLabelLine

            UPDATE PickDetail SET Qty = @nPackQty, DropID = @cLabelNo, CaseID = @cLabelNo, ArchiveCop = NULL    -- Reduce original Qty
            WHERE PickDetailKey = @cPickDetailKey
        END
        ELSE
        BEGIN
            --PRINT('Updating PackDetail in @nPickQty = @nPackQty...' + @cLabeLNo + ', ' + @cLabelLine)   --SY02

            UPDATE PackDetail SET DropID = @cLabelNo, ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
            AND SKU = @cSKU
            AND LabelNo = @cLabeLNo
            AND LabelLine = @cLabelLine

            UPDATE PickDetail SET CaseID = @cLabelNo, DropID = @cLabelNo, ArchiveCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
        END
    END
    --END

    FETCH NEXT FROM CUR INTO @cOrderKey, @cSKU
    END
    CLOSE CUR
    DEALLOCATE CUR
    DROP TABLE #TempTable

  END

  --UPDATE PACKHEADER TO STATUS 9
  UPDATE PACKHEADER SET STATUS = '9' WHERE PICKSLIPNO = @c_PickSlipNo

END

GO