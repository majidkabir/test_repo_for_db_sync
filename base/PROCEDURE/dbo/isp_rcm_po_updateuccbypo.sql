SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_PO_UpdateUCCByPO                           */
/* Creation Date: 22-Mar-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16604 - [CN] NIKESDC-NewRCM to Update UCC Fields        */
/*                                                                      */
/* Called By: PO Dynamic RCM configure at listname 'RCMConfig'          */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 12-May-2021  WLChooi   1.1   WMS-17032 - Modify Logic to Update      */
/*                              Userdefine10 (WL01)                     */
/* 08-Jun-2021  WLChooi   1.2   Remove Filter by ExternPOKey (WL02)     */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_RCM_PO_UpdateUCCByPO]
   @c_POKey    NVARCHAR(10),   
   @b_success  INT           OUTPUT,
   @n_err      INT           OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30) = ''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @n_continue           INT,
             @n_cnt                INT,
             @n_starttcnt          INT
             
   DECLARE   @dt_PODate            DATETIME,
             @dt_POEndDate         DATETIME,
             @c_Storerkey          NVARCHAR(15),
             @c_GetPOKey           NVARCHAR(10),
             @c_GetASNStatus       NVARCHAR(10),
             @c_GetUCCNo           NVARCHAR(20),
             @c_GetFacility        NVARCHAR(5),
             @n_FUDF01             INT,
             @n_FUDF02             INT,
             @n_CountSKU           INT = 0,
             @n_SumQty             INT = 0,
             @n_CountUCCNo         INT = 0,
             @c_GetSKU             NVARCHAR(20),
             @c_GetOtherReference  NVARCHAR(18),
             @c_GetUCCUDF07        NVARCHAR(30),
             @c_ExternPOKey        NVARCHAR(50)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0
   
   SELECT @dt_PODate   = CAST(CAST(PO.PODate AS DATE) AS DATETIME)    --Reset time to 00:00:00.000
        , @c_Storerkey = PO.StorerKey
   FROM PO (NOLOCK)
   WHERE PO.POKey = @c_POKey

   SET @dt_POEndDate = DATEADD(DAY, 1, @dt_PODate)

   CREATE TABLE #TMP_UCC (
      UCCNo      NVARCHAR(50)
   )

   CREATE NONCLUSTERED INDEX IDX_TMP_UCC ON #TMP_UCC (UCCNo)

   INSERT INTO #TMP_UCC (UCCNo)
   SELECT DISTINCT UCC.UCCNo
   FROM PO (NOLOCK)
   JOIN PODETAIL (NOLOCK) ON PODETAIL.POKey = PO.POKey
   JOIN UCC (NOLOCK) ON UCC.ExternKey = PO.ExternPOKey AND UCC.Storerkey = PO.StorerKey
   LEFT JOIN RECEIPT (NOLOCK) ON RECEIPT.ExternReceiptKey = PO.ExternPOKey AND RECEIPT.StorerKey = PO.StorerKey
   WHERE PO.StorerKey = @c_Storerkey
   AND PO.UserDefine01 NOT IN ('CHN-3417','CHN-3460','CHN-3728')
   AND PO.[Status] = '0'
   AND (PO.PODate >= @dt_PODate AND PO.PODate < @dt_POEndDate)
   AND (RECEIPT.ASNStatus IS NULL OR RECEIPT.ASNStatus = '0')

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PO.POKey, UCC.UCCNo, ISNULL(RECEIPT.ASNStatus,'')
                    , PODETAIL.Facility, PO.OtherReference, UCC.Userdefined07
                    , PO.ExternPOKey
      FROM PO (NOLOCK)
      JOIN PODETAIL (NOLOCK) ON PODETAIL.POKey = PO.POKey
      JOIN UCC (NOLOCK) ON UCC.ExternKey = PO.ExternPOKey AND UCC.Storerkey = PO.StorerKey
      LEFT JOIN RECEIPT (NOLOCK) ON RECEIPT.ExternReceiptKey = PO.ExternPOKey AND RECEIPT.StorerKey = PO.StorerKey
      WHERE PO.StorerKey = @c_Storerkey
      AND PO.UserDefine01 NOT IN ('CHN-3417','CHN-3460','CHN-3728')
      AND PO.[Status] = '0'
      AND (PO.PODate >= @dt_PODate AND PO.PODate < @dt_POEndDate)
      ORDER BY PO.POKey, UCC.UCCNo
   
   OPEN CUR_LOOP
      
   FETCH NEXT FROM CUR_LOOP INTO @c_GetPOKey, @c_GetUCCNo, @c_GetASNStatus
                               , @c_GetFacility, @c_GetOtherReference, @c_GetUCCUDF07
                               , @c_ExternPOKey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --Check if the PO has been populate into ASN, if yes, check ASNStatus also, must be = 0
      IF ISNULL(@c_GetASNStatus,'') <> ''
      BEGIN
         IF ISNULL(@c_GetASNStatus,'') <> '0'
         BEGIN
            GOTO NEXT_LOOP
         END
      END
      
      SELECT @n_CountSKU = COUNT(DISTINCT UCC.SKU)
           , @n_SumQty   = SUM(UCC.Qty)
           , @c_GetSKU   = MAX(UCC.SKU)
      FROM UCC (NOLOCK)
      WHERE UCC.UCCNo = @c_GetUCCNo AND UCC.Storerkey = @c_Storerkey
      AND UCC.ExternKey = @c_ExternPOKey
      
      SELECT @n_CountUCCNo = COUNT(DISTINCT UCC.UCCNo) 
      FROM UCC (NOLOCK)
      JOIN #TMP_UCC TU ON TU.UCCNo = UCC.UCCNo
      WHERE UCC.SKU = @c_GetSKU AND UCC.Storerkey = @c_Storerkey
      AND UCC.Qty = @n_SumQty
      --AND UCC.ExternKey = @c_ExternPOKey   --WL02
      
      SELECT @n_FUDF01 = CASE WHEN ISNUMERIC(F.UserDefine01) = 1 THEN CAST(F.UserDefine01 AS INT) ELSE 0 END
           , @n_FUDF02 = CASE WHEN ISNUMERIC(F.UserDefine02) = 1 THEN CAST(F.UserDefine02 AS INT) ELSE 0 END
      FROM FACILITY F (NOLOCK)
      WHERE F.Facility = @c_GetFacility
      
      --If count(UCC.SKU) = 1 group by UCC.UCCNo, continue to proceed
      
      --If sum(UCC.qty) > get @UDF01 = Facility.UserDefine01 where Facility = PODetail.Facility 
      --group by UCC.UCCNo, continue to proceed
      
      --If count(UCC.UCCNo) < get @UDF02 = Facility.UserDefine02 where Facility = PODetail.Facility 
      --group by UCC.SKU, continue to proceed
      IF @n_CountSKU = 1 AND @n_SumQty > @n_FUDF01 AND @n_CountUCCNo < @n_FUDF02
      BEGIN
         UPDATE UCC WITH (ROWLOCK)
         SET Userdefined09 = '1'
         WHERE UCCNo = @c_GetUCCNo AND UCC.Storerkey = @c_Storerkey
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3 
            SELECT @n_Err = 66500
            SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update UCC.Userdefine09 Failed for UCCNo# ' 
                            + LTRIM(RTRIM(@c_GetUCCNo)) + '. (ispTSKD09)'
            GOTO QUIT_SP
         END
      END

      --If UCC.Userdefine07 <> '1' AND (LEFT(UCCNo, 2) = 'BZ' OR PO.OtherReference = '1039')
      --If sum(UCC.qty) > get @UDF01 = Facility.UserDefine01 where Facility = PODetail.Facility   --WL01 
      --group by UCC.UCCNo, continue to proceed   --WL01
      IF @c_GetUCCUDF07 <> '1' AND (LEFT(LTRIM(RTRIM(@c_GetUCCNo)), 2) = 'BZ' OR @c_GetOtherReference = '1039')
         AND @n_SumQty > @n_FUDF01   --WL01
      BEGIN
         UPDATE UCC WITH (ROWLOCK)
         SET Userdefined10 = '1'
         WHERE UCCNo = @c_GetUCCNo AND UCC.Storerkey = @c_Storerkey
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3 
            SELECT @n_Err = 66505
            SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update UCC.Userdefine10 Failed for UCCNo# ' 
                            + LTRIM(RTRIM(@c_GetUCCNo)) + '. (ispTSKD09)'
            GOTO QUIT_SP
         END
      END
      
NEXT_LOOP:
      FETCH NEXT FROM CUR_LOOP INTO @c_GetPOKey, @c_GetUCCNo, @c_GetASNStatus
                                  , @c_GetFacility, @c_GetOtherReference, @c_GetUCCUDF07
                                  , @c_ExternPOKey
   END

QUIT_SP: 
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF OBJECT_ID('tempdb..#TMP_UCC') IS NOT NULL
      DROP TABLE #TMP_UCC
   
   IF @n_continue=3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
       BEGIN
          ROLLBACK TRAN
       END
    ELSE
       BEGIN
          WHILE @@TRANCOUNT > @n_starttcnt
          BEGIN
             COMMIT TRAN
          END
       END
       execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_PO_UpdateUCCByPO'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
       BEGIN
          SELECT @b_success = 1
          WHILE @@TRANCOUNT > @n_starttcnt
          BEGIN
             COMMIT TRAN
          END
          RETURN
       END      
END -- End PROC

GO