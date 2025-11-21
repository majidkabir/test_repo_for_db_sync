SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_GetCompanyInfo                                 */  
/* Creation Date:  04-Aug-2011                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  YTWan                                                   */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Input Parameters:  @c_StorerKey  - (StorerKey)                       */  
/*                 ,  @c_Type  - (1 = Logo, 2= Address)                 */  
/*                                                                      */  
/* Output Parameters:  @c_RetVal                                        */  
/*                                                                      */  
/* Return Status:  F_CompanyInfo Fucntion                               */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:  F_CompanyInfo Fucntion                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 02-Aug-2012  NJOW01    1.0   Add new type 3,4,5,6                    */
/* 04-MAR-2014  YTWan     1.1   SOS#303595 - PH - Update Loading Sheet  */
/*                              RCM(Wan01)                              */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetCompanyInfo](
            @c_Storerkey   NVARCHAR(15)
         ,  @c_Type        NVARCHAR(1) = '1'
         ,  @c_DataWindow  NVARCHAR(60) = ''
         ,  @c_RetVal      NVARCHAR(255)  OUTPUT )  
AS  
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTranCnt       INT  
         , @n_Continue           INT
         , @n_err                INT 
         , @b_success            INT
         , @c_errmsg             NVARCHAR(255)         
         , @n_Cnt                INT
         , @c_DefaultStorerkey   NVARCHAR(15)
         , @c_DefaultLogo        NVARCHAR(60)
         , @c_Logo               NVARCHAR(255)
         , @c_Address1           NVARCHAR(45)
         , @c_Address2           NVARCHAR(45)
         , @c_Address3           NVARCHAR(45)
         , @c_Address4           NVARCHAR(45)

   SET @n_StartTranCnt     = @@TRANCOUNT  
   SET @n_Continue         = 1 
   SET @n_err              = 0
   SET @b_success          = 0
   SET @c_errmsg           = ''

   SET @n_Cnt              = 0
   SET @c_DefaultStorerkey = 'IDS'
   SET @c_DefaultLogo      = 'ids_logo_new.bmp'
   SET @c_Logo             = ''
   SET @c_Address1         = ''
   SET @c_Address2         = ''
   SET @c_Address3         = ''

   -- Get logo from Codelkup: Listname = 'RPTLOGO', Code = {Storerkey}, Long = {Datawindow}, Notes = Logo
   -- If 1 storer setup logo for more than 1 datawindow then user enter '.' after enter storerkey for eg 'XXXXX.2', 'XXXXX.3'
   IF @c_Type IN('1','3','4','5','6') AND @c_Storerkey <> '' AND @c_Storerkey <> 'IDS' AND @c_DataWindow <> ''
   BEGIN
      SELECT @c_Logo = ISNULL(CONVERT(NVARCHAR(60),Notes),'')
      FROM Codelkup WITH (NOLOCK)
      WHERE ListName = 'RPTLOGO'
      AND (Code like @c_Storerkey + '%' OR Storerkey = @c_Storerkey )   --(Wan01)
      AND Long = @c_DataWindow 

      IF @c_Logo <> '' 
      BEGIN
        SET @c_RetVal = @c_Logo
        GOTO QUIT
      END
   END

   IF @c_Storerkey = '' SET @c_Storerkey = @c_DefaultStorerkey

   SELECT @c_Logo = ISNULL(RTRIM(Logo),'')
         ,@c_Address1 = ISNULL(RTRIM(Address1),'')
         ,@c_Address2 = ISNULL(RTRIM(Address2),'')
         ,@c_Address3 = ISNULL(RTRIM(Address3),'')
         ,@c_Address4 = ISNULL(RTRIM(Address4),'')
   FROM STORER WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey

   IF @c_Type IN('1','3','4','5','6')
   BEGIN
      IF @c_Logo = '' SET @c_Logo = @c_DefaultLogo 
      SET @c_RetVal = @c_Logo
   END
   ELSE
   BEGIN
      IF @c_Address1 <> '' SET @c_RetVal = @c_RetVal + @c_Address1 + CHAR(13)
      IF @c_Address2 <> '' SET @c_RetVal = @c_RetVal + @c_Address2 + CHAR(13)
      IF @c_Address3 <> '' SET @c_RetVal = @c_RetVal + @c_Address3 + CHAR(13)
      IF @c_Address4 <> '' SET @c_RetVal = @c_RetVal + @c_Address4 + CHAR(13)
   END

   QUIT:
   IF @n_Continue=3 -- Error Occured - Process And Return
   BEGIN
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetCompanyInfo' 
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
     RETURN
   END
   ELSE
   BEGIN
     SELECT @b_success = 1  
     WHILE @@TRANCOUNT>@n_StartTranCnt
     BEGIN
         COMMIT TRAN
     END 
     RETURN
   END
END /* main procedure */  

GO