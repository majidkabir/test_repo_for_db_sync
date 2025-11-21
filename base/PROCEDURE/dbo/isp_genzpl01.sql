SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GENZPLXX                                       */
/* Creation Date: 02-Jun-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:CHONGCS                                                   */
/*                                                                      */
/* Purpose: WMS-19785 [KR] VC ZPL Ship label Generate Logic             */
/*                                                                      */
/* Called By: isp_GenZPL_interface                                      */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 02-Jun-2022  CSCHONG   1.0   Devops Scripts Combine                  */
/************************************************************************/ 
    
CREATE PROC [dbo].[isp_GENZPL01] (    
    @c_StorerKey    NVARCHAR( 15)      
   ,@c_Facility     NVARCHAR( 5)                       
   ,@c_ReportType   NVARCHAR( 10)              
   ,@c_Param01      NVARCHAR(250)   
   ,@c_Param02      NVARCHAR(250) 
   ,@c_Param03      NVARCHAR(250) 
   ,@c_Param04      NVARCHAR(250) 
   ,@c_Param05      NVARCHAR(250)    
   ,@c_PrnTemplate  NVARCHAR(MAX)     
   ,@c_ZPLCode      NVARCHAR(MAX) OUTPUT   
   ,@b_success      INT           OUTPUT          
   ,@n_err          INT           OUTPUT              
   ,@c_errmsg       NVARCHAR(250) OUTPUT    
    )                                   
AS    
BEGIN
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @c_Externorderkey     NVARCHAR( 50) ,   
           @c_company            NVARCHAR( 45) ,    
           @c_trackingNo         NVARCHAR( 40) ,   
           @c_ORDDate            NVARCHAR( 10)  

  DECLARE @c_field01             NVARCHAR(80) = '',
          @c_field02             NVARCHAR(80) = '',
          @c_field03             NVARCHAR(80) = '',
          @c_field04             NVARCHAR(80) = '',
          @c_field05             NVARCHAR(80) = '',
          @c_field06             NVARCHAR(80) = '',
          @c_field07             NVARCHAR(80) = '',
          @c_field08             NVARCHAR(80) = '',
          @c_field09             NVARCHAR(80) = '',
          @c_field10             NVARCHAR(80) = '',
          @c_field11             NVARCHAR(150) = '',
          @c_field12             NVARCHAR(80) = '',
          @c_field13             NVARCHAR(80) = '',
          @c_field14             NVARCHAR(80) = '',
          @c_field15             NVARCHAR(80) = '',
          @c_field16             NVARCHAR(80) = '',
          @c_field17             NVARCHAR(150) = '',
          @c_field18             NVARCHAR(150) = ''

   SELECT @b_success = 1, @n_err = 0, @c_Errmsg = ''
       
   -- Parameter mapping    
   SELECT @c_field01      = OH.M_Country,
          @c_field02      = OH.M_Address3,
          @c_field03      = OH.M_Address1,
          @c_field04      = OH.M_Address2, 
          @c_field05      = OH.M_State,
          @c_field06      = Substring(OH.Trackingno,1,4) + '-' + Substring(OH.Trackingno,5,4)  +'-' +  Substring(OH.Trackingno,9,4) ,
          @c_field07      = OH.C_Contact1,
          @c_field08      = OH.C_Company,
          @c_field09      = SUBSTRING(OH.C_Phone1,1,LEN(OH.C_Phone1) - LEN(RIGHT(OH.C_Phone1, 4))) + '****',
          @c_field10      = SUBSTRING((ISNULL(OH.C_Address1,'') + ' ' + ISNULL(OH.c_Address2,'') + ' ' + ISNULL(OH.C_Address3,'') + ' ' + ISNULL(OH.C_Address4,'')), 1, 80),
          @c_field12      = OH.ExternOrderKey,
          @c_field13      = OH.TrackingNo,
          @c_field14      = OH.C_Phone1,
          @c_field15      = OH.M_Address4,
          @c_field16      = OH.m_contact1
   FROM ORDERS OH WITH (NOLOCK) 
   WHERE OH.externorderkey = @c_Param02
   AND OH.StorerKey = @c_Param01


   SELECT @c_field11 = ISNULL(c.notes,'')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.listname =  'LOTTELBL'
   AND C.Storerkey =@c_Param01
   AND c.code ='Field11'

   SELECT @c_field17 = ISNULL(c.notes,'')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.listname =  'LOTTELBL'
   AND C.Storerkey =@c_Param01
   AND c.code ='Field17'

   SELECT @c_field18 = ISNULL(c.notes,'')
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.listname =  'LOTTELBL'
   AND C.Storerkey =@c_Param01
   AND c.code ='Field18'



   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field01>', RTRIM( @c_field01))    
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field02>', RTRIM( @c_field02))    
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field03>', RTRIM( @c_field03))    
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field04>', RTRIM( @c_field04))    
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field05>', RTRIM( @c_field05))    
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field06>', RTRIM( @c_field06))    
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field07>', RTRIM( @c_field07))    
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field08>', RTRIM( @c_field08))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field09>', RTRIM( @c_field09)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field10>', RTRIM( @c_field10)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field11>', RTRIM( @c_field11)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field12>', RTRIM( @c_field12)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field13>', RTRIM( @c_field13)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field14>', RTRIM( @c_field14)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field15>', RTRIM( @c_field15)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field16>', RTRIM( @c_field16)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field17>', RTRIM( @c_field17)) 
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field18>', RTRIM( @c_field18)) 
    
   SET @c_ZPLCode = @c_PrnTemplate                  
END   
       
Quit_SP:  

GO