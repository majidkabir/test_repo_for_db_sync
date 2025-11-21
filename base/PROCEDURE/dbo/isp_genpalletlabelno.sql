SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GenPalletLabelNo                                */
/* Creation Date: 23-Jan-2019                                           */
/* Copyright: LFL                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose: WMS-7739 - To generate custom running number for            */                    
/*                     pallet printing                                  */
/*                                                                      */
/* Input Parameters:  @c_storerkey, @c_labelsize, @c_prefix, @c_Code2   */
/*                                                                      */
/*                                                                      */
/* Output Parameters: @c_labelno, @b_success, @n_Err, @c_ErrMsg         */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */ 
/************************************************************************/
CREATE PROC [dbo].[isp_GenPalletLabelNo] ( 
         @c_storerkey    NVARCHAR(30) 
      ,  @c_labelsize    NVARCHAR(10) 
      ,  @c_prefix       NVARCHAR(30)    
      ,  @c_Code2        NVARCHAR(60)
      ,  @c_labelno      NVARCHAR(20)  OUTPUT
      ,  @b_success      INT           OUTPUT
      ,  @n_Err          INT           OUTPUT        
      ,  @c_ErrMsg       NVARCHAR(250) OUTPUT        
      ,  @b_debug        INT = 0      
)
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  @n_Continue       INT
           ,@n_StartTCnt      INT
           ,@c_discretePack   NVARCHAR(5)
           ,@c_Orderkey       NVARCHAR(10)
           ,@c_ExternOrderkey NVARCHAR(30)
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
          ,@c_Keyname       NVARCHAR(18)
          ,@c_facility      NVARCHAR(5)
          ,@n_len           INT
          ,@c_LabelNoRange  NVARCHAR(20)
          ,@c_OrderGroup    NVARCHAR(20)
          ,@n_PrevCounter   BIGINT
          ,@n_NextCounter   BIGINT
          

   SELECT @n_StartTCnt = @@TRANCOUNT, @n_continue=1, @b_success=1, @c_errmsg='', @n_err=0 

	   IF(@n_continue = 1 OR @n_continue = 2)
	   BEGIN
		   SET @c_labelsize = RIGHT('00' + LTRIM(RTRIM(ISNULL(@c_labelsize,''))),2)

		   SELECT TOP 1  @c_Keyname = ISNULL(CLK.Long,''),
						  @n_Len            = ISNULL(CLK.Short,0),
						  @n_Min            = CASE WHEN ISNUMERIC(UDF01) = 1 THEN CAST(UDF01 AS BIGINT) ELSE 0 END,
						  @n_Max            = CASE WHEN ISNUMERIC(UDF02) = 1 THEN CAST(UDF02 AS BIGINT) ELSE 0 END
		   FROM CODELKUP CLK (NOLOCK)
		   WHERE CLK.LISTNAME = 'PLTLBLNUM' AND CLK.STORERKEY = @c_storerkey
		   AND CLK.CODE = @c_labelsize AND CLK.CODE2 = @c_Code2
	   END

	   IF @@ROWCOUNT = 0 
	   BEGIN
	   	GOTO QUIT_SP
	   END

	   IF(@n_continue = 1 OR @n_continue = 2)
	   BEGIN 
	       --Check if the Min value is larger than Max value
	       IF ( (@n_Min > @n_Max) AND (@n_Min <> '' AND @n_Max <> '') )
		   BEGIN
      		 SELECT @n_continue = 3  
      		 SELECT @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      		 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UDF01 > UDF02. Please Check the Codelkup Settings. (isp_GenPalletLabelNo)' 
      		 GOTO QUIT_SP
		   END

	       --Check Keyname if empty, Keyname = Storerkey_LabelSize
		   IF(ISNULL(@c_Keyname,'') = '')
			SET @c_Keyname = RTRIM(@c_storerkey) + '_' + LTRIM(@c_labelsize)
		   
		   --Check Keyname and Code2 if not empty, Keyname = Storerkey_LabelSize_Code2
		   IF(ISNULL(@c_Keyname,'') <> '' AND ISNULL(@c_Code2,'') <> '')
			SET @c_Keyname = @c_Keyname + '_' + LTRIM(@c_Code2)

		   --If Short = '' and UDF01 = '' and UDF02 <> '', 10-len(prefix) as Length of running number, Min = 1
		   IF( (ISNULL(@n_Len,0) = 0 AND ISNULL(@n_Len,'') = '') AND (ISNULL(@n_Min,0) = 0 AND ISNULL(@n_Min,'') = '') AND (ISNULL(@n_Max,0) <> 0 AND ISNULL(@n_Max,'') <> '') )
		   BEGIN
			SET @n_Len = 10 - LEN(@c_prefix)
			SET @n_Min = 1
		   END
		   
		  --If Short = '' and UDF01 = '' and UDF02 = '', 10-len(prefix) as Length of running number, Min = 1, Max = REPLICATE('9', (10 - LEN(PREFIX)))
		  IF( (ISNULL(@n_Len,0) = 0 AND ISNULL(@n_Len,'') = '') AND (ISNULL(@n_Min,0) = 0 AND ISNULL(@n_Min,'') = '') AND (ISNULL(@n_Max,0) = 0 AND ISNULL(@n_Max,'') = '') )
		  BEGIN
			SET @n_Len = 10 - LEN(@c_prefix)
			SET @n_Min = 1
			SET @n_Max = REPLICATE('9', (10 - LEN(@c_prefix)))
		  END

		  --If Short = '' and UDF01 <> '' and UDF02 = '', 10-len(prefix) as Length of running number, Max = REPLICATE('9', (10 - LEN(PREFIX)))
		  IF( (ISNULL(@n_Len,0) = 0 AND ISNULL(@n_Len,'') = '') AND (ISNULL(@n_Min,0) <> 0 AND ISNULL(@n_Min,'') <> '') AND (ISNULL(@n_Max,0) = 0 AND ISNULL(@n_Max,'') = '') )
		  BEGIN
			SET @n_Len = 10 - LEN(@c_prefix)
			SET @n_Max = REPLICATE('9', (10 - LEN(@c_prefix)))
		  END

		  --If Short = '' and UDF01 <> '' and UDF02 <> '', 10-len(prefix) as Length of running number
		  IF( (ISNULL(@n_Len,0) = 0 AND ISNULL(@n_Len,'') = '') AND (ISNULL(@n_Min,0) <> 0 AND ISNULL(@n_Min,'') <> '') AND (ISNULL(@n_Max,0) <> 0 AND ISNULL(@n_Max,'') <> '') )
		  BEGIN
			SET @n_Len = 10 - LEN(@c_prefix)
		  END

		  --If Short <> '' and UDF01 = '' and UDF02 = '', Length of running number is pre-set, Max = REPLICATE('9', (10 - LEN(PREFIX)))
		  IF( (ISNULL(@n_Len,0) <> 0 AND ISNULL(@n_Len,'') <> '') AND (ISNULL(@n_Min,0) = 0 AND ISNULL(@n_Min,'') = '') AND (ISNULL(@n_Max,0) = 0 AND ISNULL(@n_Max,'') = '') )
		  BEGIN
			SET @n_Min = 1
			SET @n_Max = REPLICATE('9', (10 - LEN(@c_prefix)))
		  END

		  --If Short <> '' and UDF01 = '' and UDF02 <> '', Length of running number is pre-set, Min = 1
		  IF( (ISNULL(@n_Len,0) <> 0 AND ISNULL(@n_Len,'') <> '') AND (ISNULL(@n_Min,0) = 0 AND ISNULL(@n_Min,'') = '') AND (ISNULL(@n_Max,0) <> 0 AND ISNULL(@n_Max,'') <> '') )
		  BEGIN
			SET @n_Min = 1
		  END

		  --If Short <> '' and UDF01 <> '' and UDF02 = '', Length of running number is pre-set, REPLICATE('9', Short)
		  IF( (ISNULL(@n_Len,0) <> 0 AND ISNULL(@n_Len,'') <> '') AND (ISNULL(@n_Min,0) <> 0 AND ISNULL(@n_Min,'') <> '') AND (ISNULL(@n_Max,0) = 0 AND ISNULL(@n_Max,'') = '') )
		  BEGIN
			SET @n_Max = REPLICATE('9', @n_Len)
		  END
		   
	   END

	   IF (@b_debug = 1)
	   SELECT @c_Keyname, @n_Len

	   IF(@n_continue = 1 OR @n_continue = 2)
	   BEGIN
	
		   EXECUTE dbo.nspg_GetKeyMinMax   
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
			 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(' + RTRIM(ISNULL(@c_keyname,'')) + ') (isp_GenPalletLabelNo)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
			 GOTO QUIT_SP
		  END     
      
		  SET @c_LabelNo = RTRIM(@c_prefix) + LTRIM(@c_LabelNoRange)
		 
			 IF (@b_debug = 1)
			 SELECT @c_LabelNo
      
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
		  EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GenPalletLabelNo"
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