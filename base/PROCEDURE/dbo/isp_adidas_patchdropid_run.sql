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
  
CREATE  PROCEDURE [dbo].[isp_ADIDAS_PATCHDROPID_RUN] (  
   @nOrderkey_input    NVARCHAR( 10)  
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
   @n_CartonNo INT = 0,
   @b_Success INT = 0,
   @c_LabelNo NVARCHAR(20),
   @cLabelLine NVARCHAR(5),
   @cNewLabelLine NVARCHAR(5),
   @c_SKU NVARCHAR(20),
   @cPickDetailKey NVARCHAR(10),
   @c_PKD_PickDetailKey_New NVARCHAR(10),
   @c_ErrMsg NVARCHAR(250),
   @n_PickDetailQty INT, @n_PackDetailQty INT, @n_PickDetailCount INT,
   @n_AdjustQty INT, @n_AdjustQty_Balance INT, @n_PickDetailLineQty INT,
   @cOrderKey NVARCHAR(10) = @nOrderkey_input,
   @c_PickSlipNo NVARCHAR(10) = '',
   @c_D_SKU NVARCHAR(20), @c_PickDetailKey NVARCHAR(10),
   @TTL_PICKQTY INT, @TTL_PACKQTY INT,
   @PHCOUNT INT, @cPickSlipNo NVARCHAR(10)

   SET @PHCOUNT = 0  
   SELECT @PHCOUNT = COUNT(1) FROM AUWMS..PACKHEADER WITH (NOLOCK) WHERE  
   STORERKEY = 'ADIDAS' AND ORDERKEY = @nOrderkey_input  
  
   IF @PHCOUNT <> 1  
   BEGIN  
       SELECT 'PACKHEADER NOT MATCH'  
   END  
   ELSE  
   BEGIN  

   SELECT @cPickSlipNo = PICKSLIPNO FROM PACKHEADER (NOLOCK) WHERE ORDERKEY = @cOrderKey

   UPDATE PICKDETAIL SET DROPID = '', CASEID = '', TRAFFICCOP = NULL, ARCHIVECOP = NULL WHERE
   ORDERKEY = @cOrderKey

   UPDATE PACKDETAIL SET DROPID = LABELNO, ARCHIVECOP = NULL WHERE PICKSLIPNO = @cPickSlipNo

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
   FETCH NEXT FROM CUR INTO @cOrderKey, @c_SKU
   WHILE @@FETCH_STATUS <> -1
   BEGIN

   SET @cPickDetailKey = ''
   SET @c_LabelNo = ''
   SET @cLabelLine = ''
   SET @nIsDone = 0
   SET @n_CartonNo = 0

   WHILE @nIsDone = 0
   BEGIN
      SET @nDiffQty = 0
      SET @n_CartonNo = 0

      SELECT TOP 1 @cPickDetailKey = PickDetailKey, @nPickQty = Qty FROM PickDetail (NOLOCK)
      WHERE OrderKey = @cOrderKey
      AND SKU = @c_SKU
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
         @n_CartonNo = CartonNo,
         @c_PickSlipNo = PD.PickSlipNo,
         @c_LabelNo = LabelNo,
         @cLabelLine = LabelLine,
         @nPackQty = Qty
      FROM PackDetail PD (NOLOCK)
      JOIN PackHeader PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      WHERE OrderKey = @cOrderKey
      AND SKU = @c_SKU
      AND PH.StorerKey = 'ADIDAS'
      AND LabelNo + LabelLine > @c_LabelNo + @cLabelLine
      --AND DropID = ''
      ORDER BY LabelNo, LabelLine

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nIsDone = 1
         BREAK
      END

      IF @nPickQty < @nPackQty
      BEGIN
         SET @nDiffQty = @nPackQty - @nPickQty

         SELECT @cNewLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5) FROM PackDetail (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
   AND CartonNo = @n_CartonNo

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
         WHERE PickSlipNo = @c_PickSlipNo
         AND SKU = @c_SKU
         AND LabelNo = @c_LabelNo
         AND LabelLine = @cLabelLine

         UPDATE PackDetail SET ArchiveCop = NULL     -- RESET ARCHIVECOP
         WHERE PickSlipNo = @c_PickSlipNo
         AND SKU = @c_SKU
         AND LabelNo = @c_LabelNo
         AND LabelLine = @cNewLabelLine

         --PRINT('Updating PackDetail in @nPickQty < @nPackQty...' + @c_LabelNo + ', ' + @cLabelLine)   --SY02

         UPDATE PackDetail SET Qty = @nPickQty, DropID = @c_LabelNo, ArchiveCop = NULL     -- Reduce original Qty
         WHERE PickSlipNo = @c_PickSlipNo
         AND SKU = @c_SKU
         AND LabelNo = @c_LabelNo
         AND LabelLine = @cLabelLine

         UPDATE PickDetail SET CaseID = @c_LabelNo, DropID = @c_LabelNo, ArchiveCop = NULL
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

         --PRINT('Updating PackDetail in @nPickQty > @nPackQty...' + @c_LabelNo + ', ' + @cLabelLine)   --SY02

         UPDATE PackDetail SET DropID = @c_LabelNo, ArchiveCop = NULL
         WHERE PickSlipNo = @c_PickSlipNo
         AND SKU = @c_SKU
         AND LabelNo = @c_LabelNo
         AND LabelLine = @cLabelLine

         UPDATE PickDetail SET Qty = @nPackQty, DropID = @c_LabelNo, CaseID = @c_LabelNo, ArchiveCop = NULL    -- Reduce original Qty
         WHERE PickDetailKey = @cPickDetailKey
      END
      ELSE
      BEGIN
         --PRINT('Updating PackDetail in @nPickQty = @nPackQty...' + @c_LabelNo + ', ' + @cLabelLine)   --SY02

         UPDATE PackDetail SET DropID = @c_LabelNo, ArchiveCop = NULL
         WHERE PickSlipNo = @c_PickSlipNo
         AND SKU = @c_SKU
         AND LabelNo = @c_LabelNo
         AND LabelLine = @cLabelLine

         UPDATE PickDetail SET CaseID = @c_LabelNo, DropID = @c_LabelNo, ArchiveCop = NULL
         WHERE PickDetailKey = @cPickDetailKey
      END
   END
   --END

   FETCH NEXT FROM CUR INTO @cOrderKey, @c_SKU
   END
   CLOSE CUR
   DEALLOCATE CUR
   DROP TABLE #TempTable


   END

 

GO