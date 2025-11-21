SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispCHNLHLD04                                       */
/* Creation Date: 24-MAY-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-20812 MY SKECHERS Auto channel transfer for ECOM when   */   
/*          channel qty short                                           */
/*                                                                      */
/* Called By: isp_ChannelAllocGetHoldQty_Wrapper from allocation        */
/*            Storerconfig: ChannelAllocGetHoldQty_SP                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 07-AUG-2023  NJOW01   1.0  WMS-23339 TH calculate channel hold qty by*/
/*                            loc category configure at codelkup.       */ 
/* 07-AUG-2023  NJOW01   1.0  DEVOPS Combine Script                     */
/* 16-AUG-2023  NJOW02   1.1  WMS-23436 support create channel transfer */
/*                            document                                  */
/************************************************************************/

CREATE   PROC [dbo].[ispCHNLHLD04]   
   @c_StorerKey        NVARCHAR(15), 
   @c_Sku              NVARCHAR(20),  
   @c_Facility         NVARCHAR(5),           
   @c_Lot              NVARCHAR(10),
   @c_Channel          NVARCHAR(20),
   @n_Channel_ID       BIGINT = 0,   
   @n_AllocateQty      INT = 0,
   @n_QtyLeftToFulFill INT = 0,
   @c_SourceKey        NVARCHAR(30) = '',
   @c_SourceType       NVARCHAR(50) = '',
   @n_ChannelHoldQty   INT      OUTPUT,
   @b_Success          INT      OUTPUT,
   @n_Err              INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT    
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue       INT,
           @n_StartTCnt      INT
                                                                 
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	   
   DECLARE @c_C_Attribute01           NVARCHAR(30)=''
          ,@c_C_Attribute02           NVARCHAR(30)=''
          ,@c_C_Attribute03           NVARCHAR(30)=''
          ,@c_C_Attribute04           NVARCHAR(30)=''
          ,@c_C_Attribute05           NVARCHAR(30)=''
          ,@n_Trf_Channel_ID          BIGINT = 0
          ,@c_Trf_Channel             NVARCHAR(20) = 'AD'
          ,@n_Trf_ChannelQtyAvailable INT = 0
          ,@n_ChannelQtyAvailable     INT = 0
          ,@n_ChannelQtyShort         INT = 0      
          ,@n_ChannelQtyToTrf         INT = 0
          ,@n_ToChannel_ID            BIGINT = 0
          ,@c_CustomerRefNo           NVARCHAR(30) = 'ispCHNLHLD04'
          ,@c_Reasoncode              NVARCHAR(10) = 'AD2ECOM'
          ,@c_ChannelInventoryMgmt    NVARCHAR(10) = '' 
          ,@c_Packkey                 NVARCHAR(10)
          ,@c_UOM                     NVARCHAR (10)
          ,@c_ChannelTransferkey      NVARCHAR(10)
          ,@c_GenChannelTransferDoc   NVARCHAR(5) = 'N'
          ,@c_TrfChannelFrom          NVARCHAR(200)='AD'
          ,@c_TrfChannelTo            NVARCHAR(200)='ECOM'
          ,@c_Authority               NVARCHAR(30) 
          ,@c_Option5                 NVARCHAR(4000)
          ,@c_GetCHNHoldQtyByLoc      NVARCHAR(30)  --NJOW01
                               
   SET @n_ChannelHoldQty = 0   
      
   SELECT @c_Authority = SC.Authority,
          @c_Option5 = SC.Option5
   FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'ChannelAllocGetHoldQty_SP') AS SC
   
   SELECT @c_TrfChannelFrom = dbo.fnc_GetParamValueFromString('@c_TrfChannelFrom', @c_Option5, @c_TrfChannelFrom)
   SELECT @c_TrfChannelTo = dbo.fnc_GetParamValueFromString('@c_TrfChannelTo', @c_Option5, @c_TrfChannelTo)
   SELECT @c_GetCHNHoldQtyByLoc = dbo.fnc_GetParamValueFromString('@c_GetCHNHoldQtyByLoc', @c_Option5, @c_GetCHNHoldQtyByLoc)  --NJOW01
   SELECT @c_GenChannelTransferDoc = dbo.fnc_GetParamValueFromString('@c_GenChannelTransferDoc', @c_Option5, @c_GenChannelTransferDoc)  --NJOW02
   
   SELECT @c_ChannelInventoryMgmt = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ChannelInventoryMgmt') 
   
   IF @c_ChannelInventoryMgmt <> '1' OR @n_Channel_ID = 0 
      GOTO QUIT_SP

   --NJOW01 
   IF @c_GetCHNHoldQtyByLoc = 'Y'
   BEGIN   	     	  
   	  SELECT @n_ChannelHoldQty = SUM(SL.Qty)
   	  FROM SKUXLOC SL (NOLOCK)
   	  JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc
   	  JOIN CODELKUP CL (NOLOCK) ON LOC.LocationCategory = CL.Code AND CL.ListName = 'CNLOCAT' AND SL.Storerkey = CL.Storerkey
   	                               AND CL.Short = @c_Channel
   	  WHERE SL.Storerkey = @c_Storerkey
   	  AND SL.Sku = @c_Sku
   	  AND LOC.Facility = @c_Facility
   	  
   	  SET @n_ChannelHoldQty = ISNULL(@n_ChannelHoldQty,0)   	  
   END
      
   IF NOT EXISTS(SELECT 1 FROM dbo.fnc_DelimSplit(',', @c_TrfChannelTo) WHERE colvalue = ISNULL(@c_Channel,''))        
      GOTO QUIT_SP
      
   SELECT TOP 1 @c_Trf_Channel = F.ColValue   
   FROM dbo.fnc_DelimSplit(',', @c_TrfChannelFrom) F
   WHERE F.SeqNo IN (SELECT T.SeqNo FROM dbo.fnc_DelimSplit(',', @c_TrfChannelTo) T WHERE T.ColValue = ISNULL(@c_Channel,''))
   ORDER BY F.SeqNo
   
   IF @n_continue IN(1,2)
   BEGIN
      SELECT @c_C_Attribute01 = C_Attribute01
            ,@c_C_Attribute02 = C_Attribute02     
            ,@c_C_Attribute03 = C_Attribute03     
            ,@c_C_Attribute04 = C_Attribute04     
            ,@c_C_Attribute05 = C_Attribute05
            ,@n_ChannelQtyAvailable = Qty - QtyAllocated - QtyOnHold            
      FROM CHANNELINV (NOLOCK)
      WHERE Channel_ID = @n_Channel_ID
      
      IF @n_QtyLeftToFulFill > @n_AllocateQty
         SET @n_QtyLeftToFulFill = @n_AllocateQty
            
      IF @n_ChannelQtyAvailable < @n_QtyLeftToFulFill
      BEGIN
      	 SET @n_ChannelQtyShort = @n_QtyLeftToFulFill - @n_ChannelQtyAvailable
      	 
      	 EXEC isp_ChannelGetID
            @c_StorerKey   = @c_StorerKey
           ,@c_Sku         = @c_SKU
           ,@c_Facility    = @c_Facility
           ,@c_Channel     = @c_Trf_Channel
           ,@c_LOT         = @c_Lot
           ,@n_Channel_ID  = @n_Trf_Channel_ID OUTPUT
           ,@b_Success     = @b_Success OUTPUT
           ,@n_ErrNo       = @n_Err OUTPUT
           ,@c_ErrMsg      = @c_ErrMsg OUTPUT               
         
         IF @n_Trf_Channel_ID > 0
         BEGIN
            SELECT @n_Trf_ChannelQtyAvailable = Qty - QtyAllocated - QtyOnHold        
            FROM CHANNELINV (NOLOCK)                                              
            WHERE Channel_ID = @n_Trf_Channel_ID                                     
         	  
         	  IF @n_Trf_ChannelQtyAvailable >= @n_ChannelQtyShort
         	     SET @n_ChannelQtyToTrf = @n_ChannelQtyShort
         	  ELSE
         	     SET @n_ChannelQtyToTrf = @n_Trf_ChannelQtyAvailable         	  
         	     
            IF @c_GenChannelTransferDoc = 'Y'
            BEGIN                 
               SELECT @c_Packkey = PACK.Packkey,
                      @c_UOM = PACK.PackUOM3
               FROM SKU (NOLOCK)
               JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
               WHERE SKU.Storerkey = @c_Storerkey
               AND SKU.Sku = @c_Sku       
               
               EXEC dbo.nspg_GetKey                
                  @KeyName = 'ChannelTransferKey'    
                 ,@fieldlength = 10    
                 ,@keystring = @c_ChannelTransferkey OUTPUT    
                 ,@b_Success = @b_success OUTPUT    
                 ,@n_err = @n_err OUTPUT    
                 ,@c_errmsg = @c_errmsg OUTPUT
                 ,@b_resultset = 0    
                 ,@n_batch     = 1                              
               
               INSERT INTO ChannelTransfer (  
                           ChannelTransferKey
                          ,ExternChannelTransferKey
                          ,FromStorerKey
                          ,ToStorerKey
                          ,Type
                          ,ReasonCode
                          ,CustomerRefNo
                          ,Remarks
                          ,Facility
                          ,ToFacility
                          ,UserDefine01
                          ,UserDefine02
                          ,UserDefine03
                          ,UserDefine04
                          ,UserDefine05)
               VALUES (@c_ChannelTransferkey
                       ,''
                       ,@c_Storerkey
                       ,@c_Storerkey
                       ,'AUTOTRF'
                       ,@c_Reasoncode
                       ,@c_CustomerRefNo
                       ,''
                       ,@c_Facility
                       ,@c_Facility
                       ,@c_SourceType
                       ,@c_Sourcekey
                       ,''
                       ,''
                       ,'')
                       
               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err)
                  SET @n_Err      = 62100
                  SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert CannelTransfer Failed'
                                  + '. (ispCHNLHLD04)( SQLSvr MESSAGE='
                                  + RTRIM(@c_Errmsg) + ' ) '              
                  GOTO QUIT_SP                
               END       
                      
               INSERT INTO ChannelTransferDetail (
                           ChannelTransferKey
                          ,ChannelTransferLineNumber
                          ,ExternChannelTransferKey
                          ,ExternChannelTransferLineNo
                          ,FromStorerKey
                          ,FromSku
                          ,FromQty
                          ,FromPackKey
                          ,FromUOM
                          ,ToStorerKey
                          ,ToSku
                          ,ToQty
                          ,ToPackKey
                          ,ToUOM
                          ,FromChannel
                          ,ToChannel
                          ,FromChannel_ID
                          ,ToChannel_ID
                          ,FromC_Attribute01
                          ,FromC_Attribute02
                          ,FromC_Attribute03
                          ,FromC_Attribute04
                          ,FromC_Attribute05
                          ,ToC_Attribute01
                          ,ToC_Attribute02
                          ,ToC_Attribute03
                          ,ToC_Attribute04
                          ,ToC_Attribute05
                          ,UserDefine01
                          ,UserDefine02
                          ,UserDefine03
                          ,UserDefine04
                          ,UserDefine05)
                VALUES (@c_ChannelTransferkey
                       ,'00001'
                       ,''
                       ,''
                       ,@c_Storerkey
                       ,@c_Sku
                       ,@n_ChannelQtyToTrf
                       ,@c_Packkey
                       ,@c_UOM
                       ,@c_Storerkey
                       ,@c_Sku           
                       ,@n_ChannelQtyToTrf
                       ,@c_Packkey
                       ,@c_UOM
                       ,@c_Trf_Channel
                       ,@c_Channel
                       ,@n_Trf_Channel_ID
                       ,@n_Channel_ID             
                       ,@c_C_Attribute01   
                       ,@c_C_Attribute02   
                       ,@c_C_Attribute03            
                       ,@c_C_Attribute04   
                       ,@c_C_Attribute05          	     
                       ,@c_C_Attribute01   
                       ,@c_C_Attribute02   
                       ,@c_C_Attribute03   
                       ,@c_C_Attribute04   
                       ,@c_C_Attribute05   
                       ,''
                       ,''
                       ,''
                       ,''
                       ,'')
                       
               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err)
                  SET @n_Err      = 62110
                  SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert CannelTransferDetail Failed'
                                  + '. (ispCHNLHLD04)( SQLSvr MESSAGE='
                                  + RTRIM(@c_Errmsg) + ' ) '
                  GOTO QUIT_SP                                                
               END       
                         
               EXEC isp_FinalizeChannelTransfer      
                  @c_ChannelTransferKey = @c_ChannelTransferkey    
                 ,@c_ChannelTransferLineNumber = ''
                 ,@b_Success = @b_Success  OUTPUT                     
                 ,@n_Err = @n_Err OUTPUT                     
                 ,@c_ErrMsg = @c_ErrMsg OUTPUT            
                 
               IF @b_Success <> 1
                  SET @n_continue = 3          
            END   
            ELSE
            BEGIN                         	                 
               EXEC  isp_FinalizeChannelInvTransfer
                        @c_Facility       = @c_Facility
                     ,  @c_Storerkey      = @c_Storerkey
                     ,  @n_Channel_id     = @n_Trf_Channel_ID
                     ,  @c_ToChannel      = @c_Channel
                     ,  @n_ToQty          = @n_ChannelQtyToTrf
                     ,  @n_ToQtyOnHold    = 0
                     ,  @c_CustomerRef    = @c_CustomerRefNo
                     ,  @c_Reasoncode     = @c_Reasoncode
                     ,  @b_Success        = @b_Success         OUTPUT
                     ,  @n_Err            = @n_Err             OUTPUT
                     ,  @c_ErrMsg         = @c_ErrMsg          OUTPUT
                     ,  @c_SourceKey      = @c_Sourcekey
                     ,  @c_SourceType     = @c_SourceType
                     ,  @c_ToFacility     = @c_Facility
                     ,  @c_ToStorerkey    = @c_Storerkey
                     ,  @c_ToSku          = @c_Sku
                     ,  @c_ToC_Attribute01= @c_C_Attribute01
                     ,  @c_ToC_Attribute02= @c_C_Attribute02
                     ,  @c_ToC_Attribute03= @c_C_Attribute03
                     ,  @c_ToC_Attribute04= @c_C_Attribute04
                     ,  @c_ToC_Attribute05= @c_C_Attribute05
                     ,  @n_ToChannel_ID   = @n_ToChannel_ID    OUTPUT         	     
                     
               IF @b_Success <> 1
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err      = 62120
                  SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Error Executing isp_FinalizeChannelInvTransfer (ispCHNLHLD04)'
               END
            END                  
         END                 	       
      END   
   END
      
QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispCHNLHLD04'		
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END  

GO