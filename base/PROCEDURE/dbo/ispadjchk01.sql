SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Proc: ispADJCHK01                                             */  
/* Creation Date: 28-DEC-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-15898 - N_PVH_AdjustmentFinalize_Validition_SP(NEW)     */  
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
/* 26-MAR-2021 CSCHONG  1.1   WMS-16673 revised logic (CS01)            */
/************************************************************************/  
CREATE PROC [dbo].[ispADJCHK01]  
           @c_AdjustmentKey  NVARCHAR(10)   
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
  
         , @c_ADJLineNo          NVARCHAR(5)  
         , @c_hostwhcode         NVARCHAR(20)
                              
         , @c_Storerkey          NVARCHAR(15)  
         , @c_Sku                NVARCHAR(20)  
         , @c_channel            NVARCHAR(20)  
         , @c_FromLoc            NVARCHAR(10)  
         , @c_FromID             NVARCHAR(18)  
         , @n_PABookingKey       INT  
  
         , @c_UserName           NVARCHAR(18)  
         , @c_MaxADJine          NVARCHAR(10) 
         , @c_GetStorerkey       NVARCHAR(20)
         , @c_LOT07              NVARCHAR(30)
         , @c_LOT08              NVARCHAR(30)

         , @c_ADJLineNoStart     NVARCHAR(5)  
         , @c_ADJLineNoEnd       NVARCHAR(5) 
         , @c_lineErr            NVARCHAR(1)
         , @c_SetErrMsg          NVARCHAR(255)
         , @c_GetErrMsg          NVARCHAR(255)

         , @n_ADJQTY             INT 
         , @n_CHQty              INT
         , @n_BLQTY              INT

         , @n_lineNo              INT
         , @n_MaxADJline          INT
  
         , @CUR_IQC              CURSOR  
         , @b_debug              NVARCHAR(1) = '0' 
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
   SET @c_UserName = SUSER_NAME()  
   SET @c_ADJLineNoStart = '00001'  
   SET @c_ADJLineNoEnd   = '99999'  
   SET @c_SetErrMsg     = ''
   SET @n_lineNo        = 1
   SET @n_MaxADJline     = 1
   SET @n_MaxADJline     = '1'
   SET @c_GetErrMsg     = ''
   SET @c_GetStorerkey  = ''

  CREATE TABLE #TMP_FVADJ01 (Storerkey       NVARCHAR(20) NULL,
                             ADJ_Key         NVARCHAR(20) NULL,
                             ADJDLineNo      NVARCHAR(10) NULL,
                             Channel         NVARCHAR(20) NULL,
                             Facility        NVARCHAR(10) NULL,
                             SKU             NVARCHAR(20) NULL,
                             hostwhcode      NVARCHAR(20) NULL,    
                             ADJQty          INT NULL DEFAULT(0),
                             LOT07           NVARCHAR(30) NULL,
                             LOT08           NVARCHAR(30) NULL)    
  
  SELECT @c_GetStorerkey = ADJ.Storerkey
  FROM   ADJUSTMENT    ADJ WITH (NOLOCK)  
  WHERE  ADJ.AdjustmentKey = @c_AdjustmentKey
  
   SELECT DISTINCT @c_GetErrMsg = CL.description
   FROM STORERCONFIG SC (NOLOCK)
   JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
   WHERE  SC.Configkey = 'ADJExtendedValidation'
   and sc.storerkey = 'PVH'
   and  CL.SHORT    = 'STOREDPROC'
   AND SC.Storerkey = @c_GetStorerkey
   AND CL.long = 'ispADJCHK01'

   INSERT INTO #TMP_FVADJ01 (Storerkey,ADJ_Key,ADJDLineNo,Channel,Facility,SKU,hostwhcode,ADJQty,LOT07,LOT08)
   SELECT DISTINCT ADJ.StorerKey,ADJ.AdjustmentKey,ADJD.AdjustmentLineNumber,ADJD.Channel,ADJ.facility,ADJD.sku,L.hostwhcode,sum(ADJD.Qty),
                   LOTT.lottable07,LOTT.lottable08
   FROM   Adjustment        ADJ  WITH (NOLOCK)  
   JOIN   ADJUSTMENTDETAIL ADJD WITH (NOLOCK) ON (ADJD.AdjustmentKey = ADJ.AdjustmentKey)  
   JOIN   LOC L WITH (NOLOCK) ON L.loc = ADJD.loc
   JOIN   Lotattribute LOTT WITH (NOLOCK) ON LOTT.lot = ADJD.Lot
   WHERE  ADJ.AdjustmentKey = @c_AdjustmentKey
   AND ADJD.Channel in ('B2B', 'B2C') 
   GROUP BY ADJ.StorerKey,ADJ.AdjustmentKey,ADJD.AdjustmentLineNumber,ADJD.Channel,ADJ.facility,ADJD.sku,L.hostwhcode,LOTT.lottable07,LOTT.lottable08
   ORDER BY ADJ.StorerKey,ADJ.AdjustmentKey,ADJD.AdjustmentLineNumber
  
  
   SET @CUR_IQC = CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT ADJDLineNo  
         ,facility  
         ,Storerkey  
         ,Sku  
         ,Channel  
         ,hostwhcode   
         ,ADJQty  
         ,LOT07
         ,LOT08
   FROM   #TMP_FVADJ01     
   WHERE  ADJ_Key = @c_AdjustmentKey  
   ORDER BY ADJDLineNo  
  
   OPEN @CUR_IQC  
     
   FETCH NEXT FROM @CUR_IQC INTO @c_ADJLineNo  
                              ,  @c_Facility  
                              ,  @c_Storerkey  
                              ,  @c_Sku  
                              ,  @c_Channel 
                              ,  @c_hostwhcode 
                              ,  @n_ADJQTY 
                              ,  @c_LOT07
                              ,  @c_LOT08
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
   --   BEGIN TRAN  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT @c_ADJLineNo '@c_ADJLineNo'  
              , @c_hostwhcode '@c_hostwhcode', @c_Channel '@c_Channel'  
              , @c_Sku '@c_Sku'  , @n_ADJQTY '@n_ADJQTY'
      END  
      
      SET   @n_CHQty = 0
      SET   @n_BLQTY = 0
      SET   @c_lineErr = 'N'

      SELECT @n_MaxADJline = COUNT(1)
      FROM #TMP_FVADJ01     
      WHERE  ADJ_Key =  @c_AdjustmentKey   

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
     --AND L.Hostwhcode = @c_hostwhcode
     AND L.Hostwhcode = case @c_channel when 'B2B' then 'BL' when 'B2C' then 'HD' else '' end 
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
         SELECT @c_ADJLineNo '@c_ADJLineNo'  
              , @c_hostwhcode '@c_hostwhcode', @c_Channel '@c_Channel'  
              , @c_Sku '@c_Sku'  , @n_ADJQTY '@n_ADJQTY',@n_CHQty '@n_CHQty', @n_BLQTY '@n_BLQTY', @c_lineErr '@c_lineErr', @c_SetErrMsg '@c_SetErrMsg'
      END 
          --CS01 START
          --IF ISNULL(@n_CHQty,0) - ISNULL(@n_BLQTY,0) + ISNULL(@n_ADJQTY,0) < 0
          -- BEGIN        
          --       SET @c_lineErr = 'Y'   
          -- END

          IF  @c_hostwhcode = 'UR'  
          BEGIN 
           IF ISNULL(@n_CHQty,0) - ISNULL(@n_BLQTY,0) + ISNULL(@n_ADJQTY,0) < 0
            BEGIN        
                 SET @c_lineErr = 'Y'   
            END
        END
         ELSE 
         BEGIN 
           IF  ISNULL(@n_BLQTY,0) + ISNULL(@n_ADJQTY,0) < 0
            BEGIN        
                 SET @c_lineErr = 'Y'   
            END
        END
        --CS01 END

      IF @b_debug = 1  
      BEGIN  
         SELECT 'A',@c_ADJLineNo '@c_ADJLineNo'  
              , @c_hostwhcode '@c_hostwhcode', @c_Channel '@c_Channel'  
              , @c_Sku '@c_Sku'  , @n_ADJQTY '@n_ADJQTY',@c_lineErr '@c_lineErr'
      END 

 IF @c_lineErr = 'Y'
 BEGIN
    IF @n_lineNo = 1
    BEGIN
       SET @c_SetErrMsg = @c_ADJLineNo
    END
    ELSE IF @n_lineNo <> @n_MaxADJline
    BEGIN
       SET @c_SetErrMsg = @c_SetErrMsg + ' ,' + @c_ADJLineNo + ','
    END
    ELSE IF @n_lineNo = @n_MaxADJline 
    BEGIN
        SET @c_SetErrMsg = @c_SetErrMsg + @c_ADJLineNo
    END
END   

SET @n_lineNo = @n_lineNo + 1

      IF @b_debug = 1  
      BEGIN  
         SELECT  @c_ADJLineNo '@c_ADJLineNo'  
              , @c_SetErrMsg '@c_SetErrMsg'
      END  
                      
FETCH NEXT FROM @CUR_IQC INTO @c_ADJLineNo  
                              ,  @c_Facility  
                              ,  @c_Storerkey  
                              ,  @c_Sku  
                              ,  @c_Channel 
                              ,  @c_hostwhcode 
                              ,  @n_ADJQTY 
                              ,  @c_LOT07
                              ,  @c_LOT08
   END  
   CLOSE @CUR_IQC  
   DEALLOCATE @CUR_IQC  
   
   IF ISNULL(@c_SetErrMsg,'') <> ''
   BEGIN
     SET @n_Continue = 3  
     SET @n_Err = 72812  
     SET @c_ErrMsg = 'Error ' + CONVERT(CHAR(5), @n_Err) + space(2) + @c_GetErrMsg + ' found on Adjustment line no : ' + RTRIM(@c_SetErrMsg)   
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