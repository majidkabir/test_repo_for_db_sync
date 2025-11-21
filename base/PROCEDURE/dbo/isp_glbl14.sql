SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL14                                          */
/* Creation Date: 26-Nov-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-7060 SG Triple Generate label no.                       */ 
/*          externorderkey +  cartonno                                  */
/*          only for dropid of normal packing and discrete packing      */
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL14'          */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */ 
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL14] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT 
      ,  @c_DropId       NVARCHAR(20) = ''
)
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  @n_Continue       INT
           ,@b_Success        INT 
           ,@n_Err            INT  
           ,@c_ErrMsg         NVARCHAR(255)
           ,@n_StartTCnt      INT
           ,@c_Storerkey      NVARCHAR(15)
           ,@c_discretePack   NVARCHAR(5)
           ,@c_Orderkey       NVARCHAR(10)
           ,@c_ExternOrderkey NVARCHAR(50)   --tlting_ext
           ,@c_ShipperKey     NVARCHAR(15)
           ,@n_MaxCartonNo    INT
           
  DECLARE  @cIdentifier      NVARCHAR(2)
           ,@cPacktype       NVARCHAR(1)
           ,@cVAT            NVARCHAR(18)
           ,@nCheckDigit     INT     
           ,@cPackNo_Long    NVARCHAR(250)
           ,@cKeyname        NVARCHAR(30) 
           ,@c_nCounter      NVARCHAR(25)
           ,@nTotalCnt       INT
           ,@nTotalOddCnt    INT
           ,@nTotalEvenCnt   INT
           ,@nAdd            INT
           ,@nDivide         INT
           ,@nRemain         INT
           ,@nOddCnt         INT
           ,@nEvenCnt        INT
           ,@nOdd            INT
           ,@nEven           INT
  
  DECLARE  @n_Min           BIGINT
          ,@n_Max           BIGINT
          --,@c_Keyname       NVARCHAR(18)
          ,@c_facility      NVARCHAR(5)
          ,@n_len           INT
          --,@c_LabelNoRange  NVARCHAR(20)
          ,@c_OrderGroup    NVARCHAR(20)
          ,@n_PrevCounter   BIGINT
          ,@n_NextCounter   BIGINT

   SELECT @n_StartTCnt=@@TRANCOUNT, @n_continue=1, @b_success=1, @c_errmsg='', @n_err=0 
   SET @c_LabelNo = ''
   SET @c_discretePack = 'Y'

   SELECT @n_MaxCartonNo = MAX(Cartonno)
   FROM		PackDetail (NOLOCK)
   WHERE  PickSlipNo = @c_Pickslipno
   
   SET @n_CartonNo = ISNULL(@n_MaxCartonNo,0) + 1    
   
   SELECT @c_Storerkey = ORDERS.Storerkey,
          @c_Orderkey = ORDERS.Orderkey,
          @c_ExternOrderkey = ORDERS.ExternOrderkey,
          @c_ShipperKey = ORDERS.Shipperkey,
          @c_OrderGroup = ORDERS.OrderGroup
   FROM PICKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PICKHEADER.PickHeaderkey = @c_Pickslipno
   
   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
      FROM PICKHEADER (NOLOCK)
      JOIN ORDERS (NOLOCK) ON PICKHEADER.ExternOrderkey = ORDERS.Loadkey
      WHERE PICKHEADER.PickHeaderkey = @c_Pickslipno
      AND ISNULL(PICKHEADER.ExternOrderkey,'') <> ''
      
      SET @c_discretePack = 'N'
   END
   
   IF @c_discretePack = 'N' AND ISNULL(@c_DropId,'') <> ''  
   BEGIN
   	   SELECT TOP 1 @c_Orderkey = O.Orderkey,
   	                @c_ExternOrderkey = O.ExternOrderkey,
   	                @c_ShipperKey = O.Shipperkey,
                    @c_OrderGroup = O.OrderGroup   	                
   	   FROM PICKDETAIL PD (NOLOCK)
   	   JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
   	   WHERE PD.DropId = @c_DropID
   	   AND O.Storerkey = @c_Storerkey   	   
   END

   IF @c_OrderGroup = 'ECOM' AND EXISTS(SELECT 1 FROM CODELKUP(NOLOCK) WHERE Listname = 'TRIPACKNO' AND Code = @c_ShipperKey AND Storerkey = @c_Storerkey)
   BEGIN   	  
      --SET @c_Keyname = 'TRI_'+LTRIM(RTRIM(@c_Shipperkey))
      SET @n_Len = 10
      
      --SELECT @n_PrevCounter = keycount
      --FROM NCOUNTER (NOLOCK)
      --WHERE Keyname = @c_keyName
            
      SELECT @n_Min = CASE WHEN ISNUMERIC(UDF01) = 1 THEN CAST(UDF01 AS BIGINT) ELSE 0 END,
             @n_Max = CASE WHEN ISNUMERIC(UDF02) = 1 THEN CAST(UDF02 AS BIGINT) ELSE 0 END,             
             @n_PrevCounter = CASE WHEN ISNUMERIC(UDF03) = 1 THEN CAST(UDF03 AS BIGINT) ELSE 0 END
      FROM CODELKUP (NOLOCK) 
   	  WHERE Listname = 'TRIPACKNO' 
   	  AND Code = @c_ShipperKey 
   	  AND Storerkey = @c_Storerkey

      IF @n_Max = 0 OR @n_Min > @n_Max
      BEGIN
      	 SELECT @n_continue = 3  
         SELECT @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid tracking no. range setup for shipperkey ''' + RTRIM(@c_Shipperkey) + ''' (isp_GLBL14)' 
         GOTO QUIT_SP
      END
   	  
      IF ISNULL(@n_PrevCounter,0) = @n_Max AND @n_Max > 0
      BEGIN
      	 SELECT @n_continue = 3  
         SELECT @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Tracking no. counter for shipperkey ''' + RTRIM(@c_Shipperkey) + ''' already hit maximum. (isp_GLBL14)' 
         GOTO QUIT_SP
      END
      
      IF ISNULL(@n_PrevCounter,0) = 0
         SET @n_nextcounter = @n_Min
      ELSE
         SET @n_nextcounter = @n_PrevCounter +  1
      
      SET @c_LabelNo = RIGHT('000000000' + LTRIM(RTRIM(CAST(@n_nextcounter AS NVARCHAR))),@n_Len)
      
      UPDATE CODELKUP WITH (ROWLOCK)
      SET UDF03 = LTRIM(RTRIM(CAST(@n_nextcounter AS NVARCHAR)))
      WHERE Listname = 'TRIPACKNO' 
      AND Code = @c_ShipperKey 
      AND Storerkey = @c_Storerkey
   	 
      /*EXECUTE dbo.nspg_GetKeyMinMax   
                @c_keyname,   
                @n_Len,   
                @n_Min,
                @n_Max,
                @c_LabelNoRange OUTPUT,   
                @b_Success OUTPUT,   
                @n_Err OUTPUT,   
                @c_Errmsg OUTPUT        
                      
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 38030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(' + RTRIM(ISNULL(@c_keyname,'')) + ') (isp_GLBL14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END     
      
      SET @c_LabelNo = @c_LabelNoRange
      */
   END
   ELSE IF ISNULL(@c_ExternOrderkey,'') <> '' AND @c_OrderGroup = 'ECOM' AND ISNULL(@c_ShipperKey,'') <> ''
           AND NOT EXISTS(SELECT 1 FROM CODELKUP(NOLOCK) WHERE Listname = 'TRIPACKNO' AND Code = @c_ShipperKey AND Storerkey = @c_Storerkey)
   BEGIN   	  
   	  SET @c_LabelNo = RTRIM(@c_ExternOrderkey) + RIGHT('000' + RTRIM(LTRIM(CAST(@n_CartonNo AS NVARCHAR))),3)
   END
   ELSE
   BEGIN    	    	
      IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK)
                  WHERE StorerKey = @c_StorerKey
                  AND ConfigKey = 'GenUCCLabelNoConfig'
                  AND SValue = '1')
      BEGIN
         SET @cIdentifier = '00'
         SET @cPacktype = '0'  
         SET @c_LabelNo = ''
      
         SELECT @cVAT = ISNULL(Vat,'')
         FROM Storer WITH (NOLOCK)
         WHERE Storerkey = @c_Storerkey
         
         IF ISNULL(@cVAT,'') = ''
            SET @cVAT = '000000000'
      
         IF LEN(@cVAT) <> 9 
            SET @cVAT = RIGHT('000000000' + RTRIM(LTRIM(@cVAT)), 9)
      
         IF ISNUMERIC(@cVAT) = 0 
         BEGIN
            SELECT @n_Continue = 3         
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Vat is not a numeric value. (isp_GLBL14)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END 
      
         SELECT @cPackNo_Long = Long 
         FROM  CODELKUP (NOLOCK)
         WHERE ListName = 'PACKNO'
         AND Code = @c_Storerkey
        
         IF ISNULL(@cPackNo_Long,'') = ''
            SET @cKeyname = 'TBLPackNo'
         ELSE
            SET @cKeyname = 'PackNo' + LTRIM(RTRIM(@cPackNo_Long))
             
         EXECUTE nspg_getkey
         @cKeyname ,
         7,
         @c_nCounter     Output ,
         @b_success      = @b_success output,
         @n_err          = @n_err output,
         @c_errmsg       = @c_errmsg output,
         @b_resultset    = 0,
         @n_batch        = 1
            
         SET @c_LabelNo = @cIdentifier + @cPacktype + RTRIM(@cVAT) + RTRIM(@c_nCounter) 
      
         SET @nOdd = 1
         SET @nOddCnt = 0
         SET @nTotalOddCnt = 0
         SET @nTotalCnt = 0
      
         WHILE @nOdd <= 20 
         BEGIN
            SET @nOddCnt = CAST(SUBSTRING(@c_LabelNo, @nOdd, 1) AS INT)
            SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
            SET @nOdd = @nOdd + 2
         END
      
         SET @nTotalCnt = (@nTotalOddCnt * 3) 
      
         SET @nEven = 2
         SET @nEvenCnt = 0
         SET @nTotalEvenCnt = 0
      
         WHILE @nEven <= 20 
         BEGIN
            SET @nEvenCnt = CAST(SUBSTRING(@c_LabelNo, @nEven, 1) AS INT)
            SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
            SET @nEven = @nEven + 2
         END
      
         SET @nAdd = 0
         SET @nRemain = 0
         SET @nCheckDigit = 0
      
         SET @nAdd = @nTotalCnt + @nTotalEvenCnt
         SET @nRemain = @nAdd % 10
         SET @nCheckDigit = 10 - @nRemain
      
         IF @nCheckDigit = 10 
            SET @nCheckDigit = 0
      
         SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
      END   -- GenUCCLabelNoConfig
      ELSE
      BEGIN
         EXECUTE nspg_GetKey
            'PACKNO', 
            10 ,
            @c_LabelNo   OUTPUT,
            @b_success  OUTPUT,
            @n_err      OUTPUT,
            @c_errmsg   OUTPUT
      END
   END   
             
   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL14"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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