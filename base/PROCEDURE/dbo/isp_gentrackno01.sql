SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GenTrackNo01                                    */
/* Creation Date: 14-July-2014                                          */
/* Copyright: LF                                                        */
/* Written by: ChewKP                                                   */
/*                                                                      */
/* Purpose:                                                             */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                                                                      */
/* Output Parameters: @c_SSCC_Barcode - SSCC barcode number             */
/*                                                                      */
/* Usage: Call from isp_GenSSCCLabel_Wrapper                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GenTrackNo01] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_LabelNo NVARCHAR(20)   
      ,  @c_TrackNo NVARCHAR(20) OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @b_debug              INT       
         , @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_Success            INT 
         , @n_Err                INT  
         , @c_ErrMsg             NVARCHAR(255)
         

   DECLARE @c_Label_PreFix       NVARCHAR(2)  
         --, @c_Label_Company      NVARCHAR(8)    
         , @c_Label_Company      NVARCHAR(10)   
         , @c_Label_SeqNo        NVARCHAR(15)  
         , @c_Label_CheckDigit   NVARCHAR(1) 
         , @c_Userdefine05       NVARCHAR(10) 
         , @c_SSCC_LabelNo       NVARCHAR(20)
         , @c_ShipperKey         NVARCHAR(15)
         , @c_SourceSystem       NVARCHAR(1)
         , @c_ISOCountrycode     NVARCHAR(10) 
         , @c_AgentNo            NVARCHAR(6)
         , @c_CountryNo          NVARCHAR(1)
         , @c_LFL_PreFix         NVARCHAR(5)
     

   DECLARE @n_SumOdd             INT
         , @n_SumEven            INT
         , @n_SumAll             INT
         , @n_Pos                INT
         , @n_Num                INT
         , @n_Try                INT

   SET @b_debug            = 0
   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   SET @c_AgentNo          = ''
   SET @c_LFL_PreFix       = ''
   
   SET @c_SourceSystem     = 'W'

             
   SET @c_Label_SeqNo      = ''
   SET @c_Label_CheckDigit = ''
   SET @c_SSCC_LabelNo     = ''

   SET @n_SumOdd  = 0
   SET @n_SumEven = 0
   SET @n_SumAll  = 0
   SET @n_Pos     = 1
   SET @n_Num     = 0
   SET @n_Try     = 0
   
   
   SELECT TOP 1 @c_ShipperKey = O.ShipperKey
               ,@c_ISOCountrycode = O.C_Country
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
   WHERE PD.PickSlipNo = @c_PickSlipNo 
   
   SELECT @c_AgentNo = Short
   FROM dbo.CodeLKup WITH (NOLOCK) 
   WHERE ListName = 'AgentNo'
   AND Code = @c_ShipperKey
   
   SELECT @c_CountryNo = Long 
   FROM dbo.Codelkup WITH (NOLOCK) 
   WHERE ListName = 'WMSCountry'
   AND Code = @c_ISOCountryCode
   
   IF @c_ShipperKey = 'LFL'
   BEGIN
      SET @c_Label_PreFix     = 'LF'      
      
      --   SELECT @c_Userdefine05 = O.Userdefine05
      --   FROM PICKHEADER PH (NOLOCK)
      --   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      --   WHERE Pickheaderkey = @c_PickslipNo 
      --   
      --   IF ISNULL(@c_Userdefine05,'') <> '' 
      --      --SET @c_Label_Company = LEFT(@c_Userdefine05,8)   
      --      SET @c_Label_Company = LEFT(@c_Userdefine05,10)    
      
         /*******************************************************************************************************/
         /* Calucuation of Check Digit                                                                          */
         /* ==========================                                                                          */
         /* Eg. SSCCLabelNo = 00093139381000000041                                                              */
         /* The last digit is a check digit and is calculated using the following formula:                      */
         /* The check digit is only based on pos 3 - 19. eg. 09313938100000004                                  */
         /* Step 1 : (Sum all odd pos.) x 3 eg. 14 x 3 = 42                                                     */
         /* Step 2 : Sum all even pos. eg. 27                                                                   */
         /* Step 3 : Step 1 + Step 2 eg. 42 + 27 = 69                                                           */
         /* Step 4 : Find the smallest number that added to the result of Step 3 will make it a multiple of 10. */
         /*******************************************************************************************************/
      
         -- Form SSCC Label
         -- Get running number
         EXECUTE dbo.nspg_GetKey
            'GlobalTrackNo',
            9,
            @c_Label_SeqNo OUTPUT,
            @b_Success     OUTPUT,
            @n_err         OUTPUT,
            @c_errmsg      OUTPUT
            
         
         
      
      
         -- Step 4
         SET @c_SSCC_LabelNo = RTRIM(@c_Label_PreFix) + RTRIM(@c_AgentNo) + RTRIM(@c_CountryNo) + RTRIM(@c_SourceSystem) + RTRIM(@c_Label_SeqNo)
         SET @c_Label_CheckDigit = dbo.fnc_ComputeCheckDigit(@c_SSCC_LabelNo) 
         SET @c_TrackNo  =  @c_SSCC_LabelNo + @c_Label_CheckDigit
         
         IF @b_debug = 1   
         BEGIN
            SELECT @c_Label_CheckDigit '@c_Label_CheckDigit', @c_SSCC_LabelNo '@c_SSCC_LabelNo' 
         END
   
   END
   ELSE IF @c_ShipperKey = 'DHL'
   BEGIN
      SET @c_LFL_PreFix     = 'HKANF'   
      
      EXECUTE dbo.nspg_GetKey
            'DHLTrackNo',
            15,
            @c_Label_SeqNo OUTPUT,
            @b_Success     OUTPUT,
            @n_err         OUTPUT,
            @c_errmsg      OUTPUT
      

      SET @c_TrackNo  =  @c_LFL_PreFix + @c_Label_SeqNo
      
      IF @b_debug = 1   
      BEGIN
         SELECT @c_Label_PreFix '@c_Label_PreFix', @c_Label_SeqNo '@c_Label_SeqNo' 
      END
   END
   
   


   

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GenTrackNo01"
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