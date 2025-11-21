SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_GenSortationCode                                  */
/* Creation Date: 11-FEB-2014                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#302522-System Generate sortation code                      */
/*        :                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[isp_GenSortationCode]  
(        @c_MBOLKey       NVARCHAR(10)    
      ,  @c_OrderKey      NVARCHAR(10)   
      ,  @c_ConsoOrderKey NVARCHAR(30)  
      ,  @c_DropID        NVARCHAR(20)   
      ,  @n_CartonNoParm  INT  
      ,  @c_LabelNoParm   NVARCHAR(20)   
      ,  @c_SortKeyName   NVARCHAR(30) 
      ,  @c_SortCode      NVARCHAR(30)    OUTPUT
      ,  @b_Success       INT             OUTPUT 
      ,  @n_Err           INT             OUTPUT 
      ,  @c_ErrMsg        NVARCHAR(250)   OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT
         , @n_Continue           INT 
         , @n_StartTCnt          INT 

         , @c_Storerkey          NVARCHAR(15)
         , @c_PickSlipNo         NVARCHAR(10)
         , @n_CartonNo           INT

         , @n_SkuCnt             INT
         , @n_MatchCnt           INT

         , @c_FdPickSlipNo       NVARCHAR(10)
         , @n_FdCartonNo         INT
         , @c_FdStorerkey        NVARCHAR(15)
         , @c_FdSku              NVARCHAR(20)
         , @n_FdQty              INT
         , @c_FdRefNo2           NVARCHAR(30)    

         , @n_FieldLength        INT
         , @n_KeyCount           INT
         , @c_Alpha              VARCHAR(1)
    
   SET @b_Success       = 1 
   SET @n_Err           = 0  
   SET @c_ErrMsg        = ''
   SET @b_Debug         = '0' 
   SET @n_Continue      = 1  
   SET @n_StartTCnt     = @@TRANCOUNT  
   
   SET @c_Storerkey     = ''
   SET @c_PickSlipNo    = ''
   SET @n_CartonNo      = 0

   SET @n_SkuCnt        = 0
   SET @n_MatchCnt      = 0

   SET @c_FdPickSlipNo  = ''
   SET @n_FdCartonNo    = 0
   SET @c_FdStorerkey   = ''
   SET @c_FdSKu         = ''
   SET @n_FdQty         = 0
   SET @c_FdRefNo2      = ''
   SET @c_SortCode      = ''


   SET @n_FieldLength   = 3
   SET @n_KeyCount      = 0
   SET @c_Alpha         = 'A'

   WHILE @@TRANCOUNT > 0 
   BEGIN
      BEGIN TRAN
   END 

   SELECT @c_PickSlipNo  = PickSlipNo
         ,@c_Storerkey   = Storerkey
   FROM PACKHEADER WITH (NOLOCK)
   WHERE ConsoOrderkey = CASE WHEN @c_ConsoOrderKey = '' OR @c_ConsoOrderKey IS NULL THEN ConsoOrderkey ELSE @c_ConsoOrderKey END
   AND   Orderkey      = CASE WHEN @c_ConsoOrderKey = '' OR @c_ConsoOrderKey IS NULL THEN @c_OrderKey ELSE Orderkey END

   SELECT @n_CartonNo = CartonNo
         ,@n_SkuCnt = COUNT(DISTINCT SKU)
         ,@c_SortCode = ISNULL(MAX(RefNo2),'')
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   AND   CartonNo   = CASE WHEN @n_CartonNoParm = 0 THEN CartonNo ELSE @n_CartonNoParm END
   AND   LabelNo    = CASE WHEN @c_LabelNoParm = '' OR @c_LabelNoParm IS NULL THEN LabelNo ELSE @c_LabelNoParm END
   GROUP BY CartonNo
   
   IF @n_CartonNo = 0
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_SortCode <> ''
   BEGIN
      GOTO QUIT_SP
   END
   --1 Consoorderkey 1 Pickslip, if pack by consoorderkey then check by pickslip else check by orderkey

   DECLARE CUR_FDPACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PD.PickSlipNo
         ,PD.CartonNo
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE PH.Storerkey = @c_Storerkey
   AND   PH.Orderkey = CASE WHEN @c_ConsoOrderKey = '' OR @c_ConsoOrderKey IS NULL THEN @c_Orderkey ELSE Orderkey END
   AND   PH.ConsoOrderKey = CASE WHEN @c_ConsoOrderKey = '' OR @c_ConsoOrderKey IS NULL THEN ConsoOrderKey ELSE @c_ConsoOrderKey END

   GROUP BY PD.PickSlipNo
         ,  PD.CartonNo
   HAVING COUNT(DISTINCT SKU) = @n_SkuCnt
   ORDER BY MIN(ISNULL(RTRIM(PD.RefNo2),'')) DESC     
  
   OPEN CUR_FDPACK  
  
   FETCH NEXT FROM CUR_FDPACK INTO @c_FdPickSlipNo
                                 , @n_FdCartonNo


   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF (@c_FdPickSlipNo = @c_PickSlipNo AND @n_FdCartonNo = @n_CartonNo)  
      BEGIN
         GOTO NEXT_FDPACK
      END 

      SET @n_MatchCnt = 0

      DECLARE CUR_FDSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PD.Storerkey
            ,PD.Sku
            ,PD.Qty
            ,ISNULL(RTRIM(PD.RefNo2),'')
      FROM PACKDETAIL PD WITH (NOLOCK) 
      WHERE PD.PickSlipNo = @c_FdPickSlipNo
      AND   PD.CartonNo = @n_FdCartonNo

      OPEN CUR_FDSKU  
  
      FETCH NEXT FROM CUR_FDSKU INTO @c_FdStorerkey
                                    ,@c_FdSku
                                    ,@n_FdQty
                                    ,@c_FdRefNo2

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF EXISTS (SELECT 1 
                    FROM PACKDETAIL WITH (NOLOCK)
                    WHERE PickSlipNo = @c_PickSlipNo
                    AND   CartonNo   = @n_CartonNo
                    AND   Storerkey  = @c_FdStorerkey
                    AND   Sku        = @c_FdSku
                    AND   Qty        = @n_FdQty)
         BEGIN
            SET @n_MatchCnt = @n_MatchCnt + 1
         END
         FETCH NEXT FROM CUR_FDSKU INTO @c_FdStorerkey
                                       ,@c_FdSku
                                       ,@n_FdQty
                                       ,@c_FdRefNo2

      END
      CLOSE CUR_FDSKU
      DEALLOCATE CUR_FDSKU

      IF @n_MatchCnt = @n_SkuCnt
      BEGIN
         SET @c_SortCode = @c_FdRefNo2
         BREAK
      END

      NEXT_FDPACK:
      FETCH NEXT FROM CUR_FDPACK INTO @c_FdPickSlipNo
                                   ,  @n_FdCartonNo
                               
   END
   CLOSE CUR_FDPACK
   DEALLOCATE CUR_FDPACK

   BEGIN TRAN
   IF @c_SortCode = '' 
   BEGIN

      -- Get SortCode
      IF NOT EXISTS (SELECT 1 FROM NCOUNTER WITH (NOLOCK) WHERE KeyName = @c_SortKeyName)    
      BEGIN
         INSERT NCOUNTER (KeyName, KeyCount, AlphaCount) VALUES (@c_SortKeyName, 0, 'A')       

         SET @n_Err = @@ERROR    
         IF @n_Err <> 0    
         BEGIN    
            SET @n_Continue = 3     
            SET @c_ErrMsg = CONVERT(char(250),@n_Err)
            SET @n_Err=61901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Insert Failed On nCounter:' + @c_SortKeyName 
                           + '. (isp_GenSortationCode)' + '( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '
            GOTO QUIT_SP    
         END 
      END  
      
      SELECT @c_Alpha    = ISNULL(RTRIM(AlphaCount),'')
            ,@n_KeyCount = ISNULL(KeyCount,0)
      FROM NCOUNTER WITH (NOLOCK) 
      WHERE  KeyName = @c_SortKeyName

      SET @n_KeyCount = @n_KeyCount + 1

      IF LEN(@n_KeyCount) > @n_FieldLength - LEN(@c_Alpha)
      BEGIN
         SET @n_KeyCount = 1

         IF @c_Alpha = 'Z'
         BEGIN
            SET @c_Alpha = 'A'
         END
         ELSE
         BEGIN
            SET @c_Alpha = master.dbo.fnc_GetCharASCII(ASCII(@c_Alpha) + 1)
         END
      END

      
      SET @c_SortCode = @c_Alpha + RIGHT('0000000000' + CONVERT(VARCHAR(10), @n_KeyCount), @n_FieldLength - LEN(@c_Alpha))

      
      UPDATE NCOUNTER WITH (ROWLOCK)
      SET KeyCount   = @n_KeyCount
         ,AlphaCount = @c_Alpha
      WHERE KeyName = @c_SortKeyName

      SET @n_Err = @@ERROR    
      IF @n_Err <> 0    
      BEGIN    
         SET @n_Continue = 3     
         SET @c_ErrMsg = CONVERT(char(250),@n_Err)
         SET @n_Err=61902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Insert Failed On NCOUNTER:' + @c_SortKeyName 
                        + '. (isp_GenSortationCode)' + '( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '
         GOTO QUIT_SP    
      END 
   END

   UPDATE PACKDETAIL WITH (ROWLOCK)
   SET  RefNo2 = @c_SortCode
      , ArchiveCop = NULL
      , EditDate   = GETDATE()
      , EditWho    = SUSER_NAME()
   WHERE PickSlipNo = @c_PickSlipNo
   AND   CartonNo   = @n_CartonNo

   SET @n_Err = @@ERROR    
   IF @n_Err <> 0    
   BEGIN    
      SET @n_Continue = 3     
      SET @c_ErrMsg = CONVERT(char(250),@n_Err)
      SET @n_Err=61903   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_ErrMsg = 'NSQL' + CONVERT(char(5),@n_Err) + ': Insert Failed On PACKDETAIL:' + @c_SortKeyName 
                     + '. (isp_GenSortationCode)' + '( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '
      GOTO QUIT_SP    
   END 

   QUIT_SP:

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END 

   IF CURSOR_STATUS('LOCAL' , 'CUR_FDPACK') in (0 , 1)
   BEGIN
      CLOSE CUR_FDPACK
      DEALLOCATE CUR_FDPACK
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GenSortationCode'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO