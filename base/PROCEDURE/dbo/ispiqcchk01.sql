SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispIQCCHK01                                             */
/* Creation Date: 18-NOV-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15568 - CN_PVH_IQCFinalizeValidation_SP_New             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 22-NOV-2022 KuanYee  1.1   INC1959510 -Remove QCLineNo grouping(KY01)*/
/************************************************************************/
CREATE   PROC [dbo].[ispIQCCHK01]
           @c_QC_Key         NVARCHAR(10)
         , @b_Success        INT            OUTPUT
         , @n_Err            INT            OUTPUT
         , @c_ErrMsg         NVARCHAR(255)  OUTPUT
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt          INT
         , @n_Continue           INT

         , @c_Facility           NVARCHAR(5)
         , @c_PhysicalFac        NVARCHAR(5)
         , @c_SuggestLoc         NVARCHAR(10)

         , @c_QCLineNo           NVARCHAR(5)
         , @c_hostwhcode         NVARCHAR(20)

         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_channel            NVARCHAR(20)
         , @c_FromLoc            NVARCHAR(10)
         , @c_FromID             NVARCHAR(18)
         , @n_PABookingKey       INT

         , @c_UserName           NVARCHAR(18)
         , @c_MaxQcline          NVARCHAR(10)
         , @c_GetStorerkey       NVARCHAR(20)
         , @c_LOT07              NVARCHAR(30)
         , @c_LOT08              NVARCHAR(30)

         , @c_QCLineNoStart      NVARCHAR(5)
         , @c_QCLineNoEnd        NVARCHAR(5)
         , @c_lineErr            NVARCHAR(1)
         , @c_SetErrMsg          NVARCHAR(255)
         , @c_GetErrMsg          NVARCHAR(255)

         , @n_IQCQTY             INT
         , @n_CHQty              INT
         , @n_BLQTY              INT

         , @n_lineNo              INT
         , @n_MaxQcline           INT

         , @CUR_IQC              CURSOR
         , @b_debug              NVARCHAR(1) = '0'

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_UserName = SUSER_NAME()
   SET @c_QCLineNoStart = '00001'
   SET @c_QCLineNoEnd   = '99999'
   SET @c_SetErrMsg     = ''
   SET @n_lineNo        = 1
   SET @n_MaxQcline     = 1
   SET @c_MaxQcline     = '1'
   SET @c_GetErrMsg     = ''
   SET @c_GetStorerkey  = ''

  CREATE TABLE #TMP_FVIQC01 (Storerkey       NVARCHAR(20) NULL,
                             QC_Key          NVARCHAR(20) NULL,
                             QCLineNo        NVARCHAR(10) NULL,
                             Channel         NVARCHAR(20) NULL,
                             Facility        NVARCHAR(10) NULL,
                             SKU             NVARCHAR(20) NULL,
                             hostwhcode      NVARCHAR(20) NULL,
                             IQCQty          INT NULL DEFAULT(0),
                             LOT07           NVARCHAR(30) NULL,
                             LOT08           NVARCHAR(30) NULL)

  SELECT @c_GetStorerkey = IQC.Storerkey
  FROM   INVENTORYQC       IQC  WITH (NOLOCK)
  WHERE  IQC.QC_Key = @c_QC_Key


   SELECT @c_GetErrMsg = description
   FROM   CODELKUP WITH (NOLOCK)
   WHERE    SHORT    = 'STOREDPROC'
   AND Storerkey = @c_GetStorerkey
   AND long = 'ispIQCCHK01'

   INSERT INTO #TMP_FVIQC01 (Storerkey,QC_Key,QCLineNo,Channel,Facility,SKU,hostwhcode,IQCQty,LOT07,LOT08)
   SELECT DISTINCT IQC.StorerKey,IQC.QC_Key,MIN(IQCD.QCLineNo) AS QCLineNo,C.UDF01,IQC.from_facility,IQCD.sku,L.hostwhcode,sum(IQCD.Qty),   --KY01
                   LOTT.lottable07,LOTT.lottable08
   FROM   INVENTORYQC       IQC  WITH (NOLOCK)
   JOIN   INVENTORYQCDETAIL IQCD WITH (NOLOCK) ON (IQC.QC_key = IQCD.QC_Key)
   JOIN   LOC L WITH (NOLOCK) ON L.loc = IQCD.fromloc
   JOIN   Lotattribute LOTT WITH (NOLOCK) ON LOTT.lot = IQCD.FromLot
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'IQCType' AND C.storerkey = IQCD.Storerkey AND C.code=IQC.Reason
   WHERE  IQC.QC_Key = @c_QC_Key
   --AND IQC.Reason in ('B2B', 'B2C')
   AND C.UDF01 in ('B2B','B2C')
   GROUP BY IQC.StorerKey,IQC.QC_Key,C.UDF01,IQC.from_facility,IQCD.sku,L.hostwhcode,LOTT.lottable07,LOTT.lottable08  --KY01
   --GROUP BY IQC.StorerKey,IQC.QC_Key,IQCD.QCLineNo,C.UDF01,IQC.from_facility,IQCD.sku,L.hostwhcode,LOTT.lottable07,LOTT.lottable08
   ORDER BY IQC.StorerKey,IQC.QC_Key--,IQCD.QCLineNo   --KY01


   SET @CUR_IQC = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT QCLineNo
         ,facility
         ,Storerkey
         ,Sku
         ,Channel
         ,hostwhcode
         ,IQCQty
         ,LOT07
         ,LOT08
   FROM   #TMP_FVIQC01
   WHERE  QC_Key = @c_QC_Key
   ORDER BY QCLineNo

   OPEN @CUR_IQC

   FETCH NEXT FROM @CUR_IQC INTO @c_QCLineNo
                              ,  @c_Facility
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_Channel
                              ,  @c_hostwhcode
                              ,  @n_IQCQTY
                              ,  @c_LOT07
                              ,  @c_LOT08

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   --   BEGIN TRAN

      IF @b_debug = 1
      BEGIN
         SELECT @c_QCLineNo '@c_QCLineNo'
              , @c_hostwhcode '@c_hostwhcode', @c_Channel '@c_Channel'
              , @c_Sku '@c_Sku'  , @n_IQCQTY '@n_IQCQTY'
      END

      SET   @n_CHQty = 0
      SET   @n_BLQTY = 0
      SET   @c_lineErr = 'N'

      SELECT @n_MaxQcline = COUNT(1)
      FROM #TMP_FVIQC01
      WHERE  QC_Key = @c_QC_Key

      SELECT @n_CHQty = ISNULL((CHINV.Qty-CHINV.QtyAllocated-CHINV.QtyOnHold),0)
      FROM Channelinv CHINV WITH (NOLOCK)
      WHERE CHINV.StorerKey = @c_Storerkey
      AND CHINV.Facility = @c_Facility
      AND CHINV.SKU = @c_Sku
      AND CHINV.Channel = @c_channel
      AND CHINV.C_Attribute01  = @c_LOT07
      AND CHINV.C_Attribute02  = @c_LOT08

     SELECT @n_BLQTY = ISNULL(sum(lli.qty - lli.qtyallocated - lli.qtypicked),0)
     FROM Lotxlocxid lli WITH (NOLOCK)
     JOIN LOC L WITH (NOLOCK) ON L.loc = lli.loc
     JOIN   Lotattribute LOTT WITH (NOLOCK) ON LOTT.lot = lli.Lot
     WHERE lli.Storerkey = @c_storerkey
     AND lli.SKU = @c_sku
     AND L.Facility = @c_facility
     AND L.Hostwhcode = CASE WHEN  @c_channel = 'B2B'  THEN 'BL'
                             WHEN  @c_channel = 'B2C'  THEN 'HD' END
     AND LOTT.lottable07  = @c_LOT07
     AND LOTT.lottable08  = @c_LOT08

     --IF @c_channel = 'B2B'
     --BEGIN
     --     SET @c_hostwhcode = 'BL'
     --END
     --ELSE IF @c_channel = 'B2C'
     --BEGIN
     --    SET @c_hostwhcode = 'HD'
     --END

     IF @b_debug = 1
      BEGIN
         SELECT @c_QCLineNo '@c_QCLineNo'
              , @c_hostwhcode '@c_hostwhcode', @c_Channel '@c_Channel'
              , @c_Sku '@c_Sku'  , @n_IQCQTY '@n_IQCQTY',@n_CHQty '@n_CHQty', @n_BLQTY '@n_BLQTY', @c_lineErr '@c_lineErr', @c_SetErrMsg '@c_SetErrMsg'
      END

     IF @c_hostwhcode = 'UR'
     BEGIN
          IF ISNULL(@n_IQCQTY,0) > (ISNULL(@n_CHQty,0) - ISNULL(@n_BLQTY,0))
           BEGIN
                 SET @c_lineErr = 'Y'
           END
     END
     ELSE
     BEGIN
          IF ISNULL(@n_IQCQTY,0) > ISNULL(@n_BLQTY,0)
          BEGIN
             SET @c_lineErr = 'Y'
          END
     END

      IF @b_debug = 1
      BEGIN
         SELECT 'A',@c_QCLineNo '@c_QCLineNo'
              , @c_hostwhcode '@c_hostwhcode', @c_Channel '@c_Channel'
              , @c_Sku '@c_Sku'  , @n_IQCQTY '@n_IQCQTY',@c_lineErr '@c_lineErr'
      END

 IF @c_lineErr = 'Y'
 BEGIN
    IF @n_lineNo = 1
    BEGIN
       SET @c_SetErrMsg = @c_QCLineNo
    END
    ELSE IF @n_lineNo <> @n_MaxQcline
    BEGIN
       SET @c_SetErrMsg = @c_SetErrMsg + ' ,' + @c_QCLineNo + ','
    END
    ELSE IF @n_lineNo = @n_MaxQcline
    BEGIN
        SET @c_SetErrMsg = @c_SetErrMsg + @c_QCLineNo
    END
END

SET @n_lineNo = @n_lineNo + 1

      IF @b_debug = 1
      BEGIN
         SELECT  @c_QCLineNo '@c_QCLineNo'
              , @c_SetErrMsg '@c_SetErrMsg'
      END

FETCH NEXT FROM @CUR_IQC INTO @c_QCLineNo
                              ,  @c_Facility
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_Channel
                              ,  @c_hostwhcode
                              ,  @n_IQCQTY
                              ,  @c_LOT07
                              ,  @c_LOT08
   END
   CLOSE @CUR_IQC
   DEALLOCATE @CUR_IQC

   IF ISNULL(@c_SetErrMsg,'') <> ''
   BEGIN
     SET @n_Continue = 3
     SET @n_Err = 81055
     SET @c_ErrMsg = 'Error ' + CONVERT(CHAR(5), @n_Err) + space(2) + @c_GetErrMsg + ' found on QC line no : ' + RTRIM(@c_SetErrMsg)
  END

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
   END

END -- procedure


GO