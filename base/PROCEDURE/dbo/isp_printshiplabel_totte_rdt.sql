SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_PrintshipLabel_totte_RDT                            */  
/* Creation Date: 26-AUG-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-17759 - [KR] TOTEME Shipping Label PB Report new        */  
/*        :                                                             */  
/* Called By: r_dw_print_shiplabel_totte_rdt                            */  
/*          : backend job                                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 28-OCT-2021  CSCHONG      Devops Scripts Combine                     */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PrintshipLabel_totte_RDT] 
            @c_storerkey   NVARCHAR(20),      
            @c_Orderkey     NVARCHAR(10)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  
  
         , @c_ExternOrderKey  NVARCHAR(50)  
         --, @c_Storerkey       NVARCHAR(15)  

         , @c_C23              NVARCHAR(80)  
         , @c_C22              NVARCHAR(80)  
         , @c_C13             NVARCHAR(80)  
         , @c_C16             NVARCHAR(80)  
         , @c_C17             NVARCHAR(80)  
         , @c_C18             NVARCHAR(80)  
         , @c_C7              NVARCHAR(80)  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 


   SELECT @c_C7  = ISNULL(MAX(CASE WHEN CL.Code = '7'  THEN ISNULL(RTRIM(CL.notes),'') ELSE '' END),'')
         ,@c_C13 = ISNULL(MAX(CASE WHEN CL.Code = '13'  THEN ISNULL(RTRIM(CL.notes),'') ELSE '' END),'')
         ,@c_C16 = ISNULL(MAX(CASE WHEN CL.Code = '16'  THEN ISNULL(RTRIM(CL.notes),'') ELSE '' END),'')
         ,@c_C17 = ISNULL(MAX(CASE WHEN CL.Code = '17'  THEN ISNULL(RTRIM(CL.notes),'') ELSE '' END),'')
         ,@c_C18 = ISNULL(MAX(CASE WHEN CL.Code = '18'  THEN ISNULL(RTRIM(CL.notes),'') ELSE '' END),'')
         ,@c_C22 = ISNULL(MAX(CASE WHEN CL.Code = '22'  THEN ISNULL(RTRIM(CL.notes),'') ELSE '' END),'')
         ,@c_C23 = ISNULL(MAX(CASE WHEN CL.Code = '23'  THEN ISNULL(RTRIM(CL.notes),'') ELSE '' END),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'LOTTELBL'

   SELECT ISNULL(OH.M_Address1,'') AS M_Address1
         , ISNULL(OH.M_Contact1,'') AS M_Contact1
         , OH.C_Contact1
         , OH.Externorderkey
         , SUBSTRING((OH.C_Address1 + ' ' + OH.C_Address2 + ' ' + OH.C_Address3 + ' ' + OH.C_Address4), 1, 80) AS CAddress
         , OH.C_Phone1         
         , SUBSTRING(OH.C_Phone1,1,LEN(OH.C_Phone1) - LEN(RIGHT(OH.C_Phone1, 4))) + '****' AS phone
         , OH.Orderkey
         , ISNULL(OH.M_Address2,'') AS M_Address2
         , ISNULL(OH.M_Address3,'') AS M_Address3
         , ISNULL(OH.M_State,'') AS MState
         , ISNULL(OH.C_Company,'') AS C_Company
         , ISNULL(OH.M_Address4,'') AS M_Address4
         , ISNULL(OH.M_Country,'') AS M_Country
         , OH.trackingno AS tackingno
         ,SUBSTRING(OH.trackingno,1,4) + '-' + Substring(OH.trackingno,5,4)  +'-' +  Substring(OH.trackingno,9,4)  AS TNO
         ,@c_C7 AS C7
         ,@c_C13 AS C13
         ,@c_C16 AS C16
         ,@c_C17 AS C17
         ,@c_C18 AS C18
         ,@c_C22 AS C22
         ,@c_c23 AS C23
   FROM ORDERS OH (NOLOCK)
   WHERE OH.Orderkey = @c_Orderkey
   GROUP BY ISNULL(OH.M_Address1,'') ,
           ISNULL(OH.M_Contact1,'')
          , OH.C_Contact1
          , SUBSTRING((OH.C_Address1 + ' ' + OH.C_Address2 + ' ' + OH.C_Address3 + ' ' + OH.C_Address4), 1, 80)
          , OH.C_Phone1
          , OH.Externorderkey
          , CONVERT(NVARCHAR(10), OH.OrderDate, 101)
          , OH.Orderkey
          , ISNULL(OH.M_Address2,'')
          , ISNULL(OH.M_Address3,'')
          , ISNULL(OH.M_state,'')
          , ISNULL(OH.M_Country,''), ISNULL(OH.M_Address4,'')
          , ISNULL(OH.C_Company,''), OH.TrackingNo
   ORDER BY OH.Orderkey

END -- procedure


GO