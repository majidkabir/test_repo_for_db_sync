SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_Create_Order_PI_Encrypted                      */
/* Creation Date: 31-Mar-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Encrypt Personal Information for Order                      */
/*                                                                      */
/* Called By: Interface                                                 */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 02-Mar-2021  Shong         Update EditWho and EditDate               */
/* 05-Mar-2021  Shong         Fixing Partial Encrypt Issues             */
/* 08-Mar-2021  TLTING02 1.3  field length extend                       */
/************************************************************************/

CREATE PROC [dbo].[isp_Create_Order_PI_Encrypted]
            @c_OrderKey       NVARCHAR(10)
          , @c_C_Contact1     NVARCHAR(100) = ''
          , @c_C_Contact2     NVARCHAR(100) = ''
          , @c_C_Company      NVARCHAR(100)  = ''
          , @c_C_Address1     NVARCHAR(45)  = ''
          , @c_C_Address2     NVARCHAR(45)  = ''
          , @c_C_Address3     NVARCHAR(45)  = ''
          , @c_C_Address4     NVARCHAR(45)  = ''
          , @c_C_City         NVARCHAR(45)  = ''
          , @c_C_State        NVARCHAR(45)  = ''
          , @c_C_Country      NVARCHAR(30)  = ''
          , @c_C_Phone1       NVARCHAR(18)  = ''
          , @c_C_Phone2       NVARCHAR(18)  = ''
          , @c_C_Zip          NVARCHAR(18)  = ''
          , @c_C_Fax1         NVARCHAR(18)  = ''
          , @c_C_Fax2         NVARCHAR(18)  = ''
          , @c_B_Contact1     NVARCHAR(100)  = ''
          , @c_B_Contact2     NVARCHAR(100)  = ''
          , @c_B_Company      NVARCHAR(100)  = ''
          , @c_B_Address1     NVARCHAR(45)  = ''
          , @c_B_Address2     NVARCHAR(45)  = ''
          , @c_B_Address3     NVARCHAR(45)  = ''
          , @c_B_Address4     NVARCHAR(45)  = ''
          , @c_B_City         NVARCHAR(45)  = ''
          , @c_B_Zip          NVARCHAR(18)  = ''
          , @c_B_Country      NVARCHAR(30)  = ''
          , @c_B_Phone1       NVARCHAR(18)  = ''
          , @c_B_Phone2       NVARCHAR(18)  = ''
          , @c_B_Fax1         NVARCHAR(18)  = ''
          , @c_B_Fax2         NVARCHAR(18)  = ''
          , @c_B_State        NVARCHAR(45)  = ''
          , @c_M_Contact1     NVARCHAR(100)  = ''
          , @c_M_Contact2     NVARCHAR(100)  = ''
          , @c_M_Company      NVARCHAR(100)  = ''
          , @c_M_Address1     NVARCHAR(45)  = ''
          , @c_M_Address2     NVARCHAR(45)  = ''
          , @c_M_Address3     NVARCHAR(45)  = ''
          , @c_M_Address4     NVARCHAR(45)  = ''
          , @c_M_City         NVARCHAR(45)  = ''
          , @c_M_Zip          NVARCHAR(45)  = ''
          , @c_M_Country      NVARCHAR(45)  = ''
          , @c_M_Phone1       NVARCHAR(45)  = ''
          , @c_M_Phone2       NVARCHAR(45)  = ''
          , @c_M_Fax1         NVARCHAR(18)  = ''
          , @c_M_Fax2         NVARCHAR(18)  = ''
          , @c_M_State        NVARCHAR(45)  = ''
          , @c_NoUpdateC      NVARCHAR(45)  = 'N'
          , @b_success        INT           = 1  OUTPUT
          , @n_ErrNo          INT           = 0  OUTPUT
          , @c_ErrMsg         NVARCHAR(250) = '' OUTPUT
AS
BEGIN
   SET @b_success = 1

   BEGIN TRY
      OPEN SYMMETRIC KEY Smt_Key_Orders_PI
      DECRYPTION BY CERTIFICATE Cert_Orders_PI;
   END TRY

   BEGIN CATCH
      SET @n_ErrNo   = ERROR_NUMBER()
      SET @c_ErrMsg  = ERROR_MESSAGE()
      SET @b_success = 0

       GOTO QUICK_SP
   END CATCH

   DECLARE 
       @vb_C_Contact1  VARBINARY (1000)
     , @vb_C_Contact2  VARBINARY (1000)
     , @vb_C_Company   VARBINARY (1000)
     , @vb_C_Address1  VARBINARY (1000)
     , @vb_C_Address2  VARBINARY (1000)
     , @vb_C_Address3  VARBINARY (1000)
     , @vb_C_Address4  VARBINARY (1000)
     , @vb_C_City      VARBINARY (1000)
     , @vb_C_State     VARBINARY (1000)
     , @vb_C_Zip       VARBINARY (1000)
     , @vb_C_Country   VARBINARY (1000)
     , @vb_C_Phone1    VARBINARY (1000)
     , @vb_C_Phone2    VARBINARY (1000)
     , @vb_C_Fax1      VARBINARY (1000)
     , @vb_C_Fax2      VARBINARY (1000)
     , @vb_B_contact1  VARBINARY (1000)
     , @vb_B_Contact2  VARBINARY (1000)
     , @vb_B_Company   VARBINARY (1000)
     , @vb_B_Address1  VARBINARY (1000)
     , @vb_B_Address2  VARBINARY (1000)
     , @vb_B_Address3  VARBINARY (1000)
     , @vb_B_Address4  VARBINARY (1000)
     , @vb_B_City      VARBINARY (1000)
     , @vb_B_State     VARBINARY (1000)
     , @vb_B_Zip       VARBINARY (1000)
     , @vb_B_Country   VARBINARY (1000)
     , @vb_B_Phone1    VARBINARY (1000)
     , @vb_B_Phone2    VARBINARY (1000)
     , @vb_B_Fax1      VARBINARY (1000)
     , @vb_B_Fax2      VARBINARY (1000)
     , @vb_M_Contact1  VARBINARY (1000)
     , @vb_M_Contact2  VARBINARY (1000)
     , @vb_M_Company   VARBINARY (1000)
     , @vb_M_Address1  VARBINARY (1000)
     , @vb_M_Address2  VARBINARY (1000)
     , @vb_M_Address3  VARBINARY (1000)
     , @vb_M_Address4  VARBINARY (1000)
     , @vb_M_City      VARBINARY (1000)
     , @vb_M_State     VARBINARY (1000)
     , @vb_M_Zip       VARBINARY (1000)
     , @vb_M_Country   VARBINARY (1000)
     , @vb_M_Phone1    VARBINARY (1000)
     , @vb_M_Phone2    VARBINARY (1000)
     , @vb_M_Fax1      VARBINARY (1000)
     , @vb_M_Fax2      VARBINARY (1000)
   
   DECLARE @c_Step1    NVARCHAR(20) = ''
         , @c_Step2    NVARCHAR(20) = ''
         , @c_Step3    NVARCHAR(20) = ''
         , @c_Step4    NVARCHAR(20) = ''
         , @c_Step5    NVARCHAR(20) = ''
   
   SELECT  @vb_C_Contact1 = EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Contact1, ''))
   IF @c_C_Contact1 <> ISNULL(CONVERT([NVARCHAR](200),   DecryptByKey(@vb_C_Contact1)),'')
   BEGIN
      SET @c_Step1 = '1'
      SELECT  @vb_C_Contact1 = EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Contact1, ''))
   END
      
   SELECT  @vb_C_Contact2 = CASE WHEN @c_C_Contact2 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Contact2, '')) END 
   SELECT  @vb_C_Company  = CASE WHEN @c_C_Company  = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Company , '')) END 
   SELECT  @vb_C_Address1 = CASE WHEN @c_C_Address1 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Address1, '')) END    
   SELECT  @vb_C_Address2 = CASE WHEN @c_C_Address2 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Address2, '')) END       
   SELECT  @vb_C_Address3 = CASE WHEN @c_C_Address3 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Address3, '')) END         
   SELECT  @vb_C_Address4 = CASE WHEN @c_C_Address4 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Address4, '')) END    
   SELECT  @vb_C_City     = CASE WHEN @c_C_City     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_City    , '')) END          
   SELECT  @vb_C_State    = CASE WHEN @c_C_State    = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_State   , '')) END 
   SELECT  @vb_C_Country  = CASE WHEN @c_C_Country  = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Country , '')) END 
   SELECT  @vb_C_Phone1   = CASE WHEN @c_C_Phone1   = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Phone1  , '')) END 
   SELECT  @vb_C_Phone2   = CASE WHEN @c_C_Phone2   = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Phone2  , '')) END 
   SELECT  @vb_C_Zip      = CASE WHEN @c_C_Zip      = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Zip     , '')) END 
   SELECT  @vb_C_Fax1     = CASE WHEN @c_C_Fax1     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Fax1    , '')) END 
   SELECT  @vb_C_Fax2     = CASE WHEN @c_C_Fax2     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_C_Fax2    , '')) END 

   SELECT  @vb_B_Contact1 = CASE WHEN @c_B_Contact1 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Contact1, '')) END
   SELECT  @vb_B_Contact2 = CASE WHEN @c_B_Contact2 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Contact2, '')) END
   SELECT  @vb_B_Company  = CASE WHEN @c_B_Company  = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Company , '')) END
   SELECT  @vb_B_Address1 = CASE WHEN @c_B_Address1 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Address1, '')) END
   SELECT  @vb_B_Address2 = CASE WHEN @c_B_Address2 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Address2, '')) END
   SELECT  @vb_B_Address3 = CASE WHEN @c_B_Address3 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Address3, '')) END
   SELECT  @vb_B_Address4 = CASE WHEN @c_B_Address4 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Address4, '')) END
   SELECT  @vb_B_City     = CASE WHEN @c_B_City     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_City    , '')) END
   SELECT  @vb_B_Zip      = CASE WHEN @c_B_Zip      = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Zip     , '')) END
   SELECT  @vb_B_Country  = CASE WHEN @c_B_Country  = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Country , '')) END
   SELECT  @vb_B_Phone1   = CASE WHEN @c_B_Phone1   = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Phone1  , '')) END
   SELECT  @vb_B_Phone2   = CASE WHEN @c_B_Phone2   = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Phone2  , '')) END
   SELECT  @vb_B_Fax1     = CASE WHEN @c_B_Fax1     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Fax1    , '')) END
   SELECT  @vb_B_Fax2     = CASE WHEN @c_B_Fax2     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_Fax2    , '')) END
   SELECT  @vb_B_State    = CASE WHEN @c_B_State    = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_B_State   , '')) END
   
   SELECT  @vb_M_Contact1 = CASE WHEN @c_M_Contact1 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Contact1, '')) END 
   SELECT  @vb_M_Contact2 = CASE WHEN @c_M_Contact2 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Contact2, '')) END 
   SELECT  @vb_M_Company  = CASE WHEN @c_M_Company  = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Company , '')) END 
   SELECT  @vb_M_Address1 = CASE WHEN @c_M_Address1 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Address1, '')) END 
   SELECT  @vb_M_Address2 = CASE WHEN @c_M_Address2 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Address2, '')) END 
   SELECT  @vb_M_Address3 = CASE WHEN @c_M_Address3 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Address3, '')) END 
   SELECT  @vb_M_Address4 = CASE WHEN @c_M_Address4 = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Address4, '')) END 
   SELECT  @vb_M_City     = CASE WHEN @c_M_City     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_City    , '')) END 
   SELECT  @vb_M_Zip      = CASE WHEN @c_M_Zip      = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Zip     , '')) END 
   SELECT  @vb_M_Country  = CASE WHEN @c_M_Country  = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Country , '')) END 
   SELECT  @vb_M_Phone1   = CASE WHEN @c_M_Phone1   = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Phone1  , '')) END 
   SELECT  @vb_M_Phone2   = CASE WHEN @c_M_Phone2   = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Phone2  , '')) END 
   SELECT  @vb_M_Fax1     = CASE WHEN @c_M_Fax1     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Fax1    , '')) END 
   SELECT  @vb_M_Fax2     = CASE WHEN @c_M_Fax2     = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_Fax2    , '')) END 
   SELECT  @vb_M_State    = CASE WHEN @c_M_State    = '' THEN NULL ELSE EncryptByKey(Key_GUID('Smt_Key_Orders_PI'),ISNULL(@c_M_State   , '')) END 
   
   IF NOT EXISTS (SELECT 1 FROM Orders_PI_Encrypted WITH (NOLOCK) WHERE Orderkey = @c_OrderKey )
   BEGIN
      INSERT INTO Orders_PI_Encrypted (
        Orderkey
      , C_Contact1,  C_Contact2,    C_Company
      , C_Address1,  C_Address2,    C_Address3
      , C_Address4,  C_City,        C_State
      , C_Country,   C_Phone1,      C_Phone2
      , C_Zip,       C_Fax1,        C_Fax2
      , B_Contact1,  B_Contact2,    B_Company
      , B_Address1,  B_Address2,    B_Address3
      , B_Address4,  B_City,        B_Zip
      , B_Country,   B_Phone1,      B_Phone2
      , B_Fax1,      B_Fax2,        B_State
      , M_Contact1,  M_Contact2,    M_Company
      , M_Address1,  M_Address2,    M_Address3
      , M_Address4,  M_City,        M_Zip
      , M_Country,   M_Phone1,      M_Phone2
      , M_Fax1,      M_Fax2,        M_State
      , AddDate,     AddWho,        EditDate
      , EditWho
      ) VALUES (
        @c_Orderkey
      , @vb_C_Contact1, @vb_C_Contact2,   @vb_C_Company
      , @vb_C_Address1, @vb_C_Address2,   @vb_C_Address3 
      , @vb_C_Address4, @vb_C_City,       @vb_C_State    
      , @vb_C_Country,  @vb_C_Phone1,     @vb_C_Phone2   
      , @vb_C_Zip,      @vb_C_Fax1,       @vb_C_Fax2     
      , @vb_B_Contact1, @vb_B_Contact2,   @vb_B_Company  
      , @vb_B_Address1, @vb_B_Address2,   @vb_B_Address3 
      , @vb_B_Address4, @vb_B_City,       @vb_B_Zip      
      , @vb_B_Country,  @vb_B_Phone1,     @vb_B_Phone2   
      , @vb_B_Fax1,     @vb_B_Fax2,       @vb_B_State    
      , @vb_M_Contact1, @vb_M_Contact2,   @vb_M_Company  
      , @vb_M_Address1, @vb_M_Address2,   @vb_M_Address3 
      , @vb_M_Address4, @vb_M_City,       @vb_M_Zip      
      , @vb_M_Country,  @vb_M_Phone1,     @vb_M_Phone2   
      , @vb_M_Fax1,     @vb_M_Fax2,       @vb_M_State    
      , GETDATE(),      SUSER_SNAME(),    GETDATE()
      , SUSER_SNAME()
      )

   END
   ELSE
   BEGIN
      IF @c_NoUpdateC = 'Y' 
      BEGIN
         UPDATE Orders_PI_Encrypted WITH (ROWLOCK)
         SET B_Contact1 = @vb_B_Contact1
           , B_Contact2 = @vb_B_Contact2
           , B_Company  = @vb_B_Company 
           , B_Address1 = @vb_B_Address1
           , B_Address2 = @vb_B_Address2
           , B_Address3 = @vb_B_Address3
           , B_Address4 = @vb_B_Address4
           , B_City     = @vb_B_City    
           , B_Zip      = @vb_B_Zip     
           , B_Country  = @vb_B_Country 
           , B_Phone1   = @vb_B_Phone1  
           , B_Phone2   = @vb_B_Phone2  
           , B_Fax1     = @vb_B_Fax1    
           , B_Fax2     = @vb_B_Fax2    
           , B_State    = @vb_B_State   
           , M_Contact1 = @vb_M_Contact1
           , M_Contact2 = @vb_M_Contact2
           , M_Company  = @vb_M_Company 
           , M_Address1 = @vb_M_Address1
           , M_Address2 = @vb_M_Address2
           , M_Address3 = @vb_M_Address3
           , M_Address4 = @vb_M_Address4
           , M_City     = @vb_M_City    
           , M_Zip      = @vb_M_Zip     
           , M_Country  = @vb_M_Country 
           , M_Phone1   = @vb_M_Phone1  
           , M_Phone2   = @vb_M_Phone2  
           , M_Fax1     = @vb_M_Fax1    
           , M_Fax2     = @vb_M_Fax2    
           , M_State    = @vb_M_State   
           , EditDate = GETDATE()
           , EditWho = SUSER_SNAME()
         WHERE Orderkey = @c_Orderkey
         
      END
      ELSE 
      BEGIN
         UPDATE Orders_PI_Encrypted WITH (ROWLOCK)
         SET C_Contact1 = @vb_C_Contact1  
           , C_Contact2 = @vb_C_Contact2  
           , C_Company  = @vb_C_Company   
           , C_Address1 = @vb_C_Address1  
           , C_Address2 = @vb_C_Address2  
           , C_Address3 = @vb_C_Address3  
           , C_Address4 = @vb_C_Address4  
           , C_City     = @vb_C_City      
           , C_State    = @vb_C_State     
           , C_Phone1   = @vb_C_Phone1    
           , C_Phone2   = @vb_C_Phone2    
           , C_Zip      = @vb_C_Zip       
           , C_Fax1     = @vb_C_Fax1      
           , C_Fax2     = @vb_C_Fax2      
           , B_Contact1 = @vb_B_Contact1
           , B_Contact2 = @vb_B_Contact2
           , B_Company  = @vb_B_Company 
           , B_Address1 = @vb_B_Address1
           , B_Address2 = @vb_B_Address2
           , B_Address3 = @vb_B_Address3
           , B_Address4 = @vb_B_Address4
           , B_City     = @vb_B_City    
           , B_Zip      = @vb_B_Zip     
           , B_Country  = @vb_B_Country 
           , B_Phone1   = @vb_B_Phone1  
           , B_Phone2   = @vb_B_Phone2  
           , B_Fax1     = @vb_B_Fax1    
           , B_Fax2     = @vb_B_Fax2    
           , B_State    = @vb_B_State   
           , M_Contact1 = @vb_M_Contact1
           , M_Contact2 = @vb_M_Contact2
           , M_Company  = @vb_M_Company 
           , M_Address1 = @vb_M_Address1
           , M_Address2 = @vb_M_Address2
           , M_Address3 = @vb_M_Address3
           , M_Address4 = @vb_M_Address4
           , M_City     = @vb_M_City    
           , M_Zip      = @vb_M_Zip     
           , M_Country  = @vb_M_Country 
           , M_Phone1   = @vb_M_Phone1  
           , M_Phone2   = @vb_M_Phone2  
           , M_Fax1     = @vb_M_Fax1    
           , M_Fax2     = @vb_M_Fax2    
           , M_State    = @vb_M_State   
           , EditDate = GETDATE()
           , EditWho = SUSER_SNAME()
         WHERE Orderkey = @c_Orderkey
      END
   END

   QUICK_SP:

END -- procedure

GO