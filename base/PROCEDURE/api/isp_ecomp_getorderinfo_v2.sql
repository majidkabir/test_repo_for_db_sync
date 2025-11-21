SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/    
/* Stored Proc: [API].[isp_ECOMP_GetOrderInfo_v2]                       */    
/* Creation Date: 14-JUN-2019                                           */    
/* Copyright: Maersk                                                    */    
/* Written by: Wan                                                      */    
/*                                                                      */    
/* Purpose: Performance Tune                                            */    
/*        :                                                             */    
/* Called By: ECOM PackHeader - ue_saveend                              */    
/*          :                                                           */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */    
/* 05-Aug-2021 NJOW01   1.0   WMS-17104 add config to skip get tracking */    
/*                            no from userdefine04                      */  
/* 08-JUL-2023 Alex01   1.1   Clone from WMS EXCEED script              */    
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetOrderInfo_v2] (
     @c_Orderkey             NVARCHAR(10)  
   , @c_OrderInfoJson        NVARCHAR(MAX)     = ''  OUTPUT
)
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_StartTCnt          INT               = @@TRANCOUNT    
         , @n_Continue           INT               = 1    
   
   DECLARE @c_ExternOrderkey     NVARCHAR(50)      = ''
         , @c_LoadKey            NVARCHAR(10)      = ''
         , @c_ConsigneeKey       NVARCHAR(15)      = ''
         , @c_ShipperKey         NVARCHAR(15)      = ''
         , @c_SalesMan           NVARCHAR(30)      = ''
         , @c_Route              NVARCHAR(10)      = ''
         , @c_UserDefine03       NVARCHAR(20)      = ''
         , @c_UserDefine04       NVARCHAR(40)      = ''
         , @c_UserDefine05       NVARCHAR(20)      = ''
         , @c_Status             NVARCHAR(30)      = ''
         , @c_SOStatus           NVARCHAR(30)      = ''
         , @c_TrackingNo         NVARCHAR(40)      = ''
         , @c_StorerKey          NVARCHAR(15)      = ''
         , @c_M_Company          NVARCHAR(100)     = ''

   SET @c_OrderInfoJson          = ''
   SET @c_Orderkey               = ISNULL(RTRIM(@c_Orderkey), '')

   IF @c_Orderkey = ''
   BEGIN
      SET @c_OrderInfoJson = '{}'
      GOTO QUIT_SP
   END

   SELECT TOP 1
       @c_StorerKey        = ORD.StorerKey
      ,@c_ExternOrderkey   = ORD.ExternOrderkey    
      ,@c_LoadKey          = ORD.LoadKey    
      ,@c_ConsigneeKey     = ORD.ConsigneeKey    
      ,@c_ShipperKey       = ORD.ShipperKey    
      ,@c_SalesMan         = ORD.SalesMan    
      ,@c_Route            = ORD.Route    
      ,@c_UserDefine03     = ORD.UserDefine03    
      ,@c_UserDefine04     = ORD.UserDefine04    
      ,@c_UserDefine05     = ORD.UserDefine05    
      ,@c_Status           = ORD.Status    
      ,@c_SOStatus         = ORD.SOStatus    
      ,@c_TrackingNo       = CASE WHEN SC.Configkey IS NOT NULL THEN ISNULL(RTRIM(ORD.TrackingNo),'') ELSE  --NJOW01    
                                  CASE WHEN ISNULL(RTRIM(ORD.TrackingNo),'') <> '' THEN ORD.TrackingNo ELSE ISNULL(RTRIM(ORD.UserDefine04),'') END    
                             END
      ,@c_M_Company        = ISNULL(RTRIM(ORD.M_Company), '')
   FROM [dbo].[ORDERS] ORD WITH (NOLOCK)    
   LEFT JOIN [dbo].[STORERCONFIG] SC (NOLOCK) ON ORD.Storerkey = SC.Storerkey AND SC.Configkey = 'EPACKGetTrackNoSkipUDF04' AND SC.Svalue = '1'  --NJOW01    
   WHERE ORD.Orderkey = @c_Orderkey    
   
   IF @c_SOStatus <> ''
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.[Codelkup] WITH (NOLOCK) 
         WHERE ListName = 'SOStatus' AND Code = @c_SOStatus AND StorerKey = @c_StorerKey )
      BEGIN
         SELECT @c_SOStatus = ISNULL(RTRIM([Description]), '') 
         FROM [dbo].[Codelkup] WITH (NOLOCK) 
         WHERE ListName = 'SOSTATUS' 
         AND Code = @c_SOStatus 
         AND StorerKey = @c_StorerKey 
      END
      ELSE IF EXISTS ( SELECT 1 FROM dbo.[Codelkup] WITH (NOLOCK) 
         WHERE ListName = 'SOSTATUS' AND Code = @c_SOStatus AND StorerKey = '' )
      BEGIN
         SELECT @c_SOStatus = ISNULL(RTRIM([Description]), '') 
         FROM [dbo].[Codelkup] WITH (NOLOCK) 
         WHERE ListName = 'SOSTATUS' 
         AND Code = @c_SOStatus 
         AND StorerKey = ''
      END
      
      IF EXISTS ( SELECT 1 FROM dbo.[Codelkup] WITH (NOLOCK) 
         WHERE ListName = 'ORDRSTATUS' AND Code = @c_Status AND StorerKey = @c_StorerKey )
      BEGIN
         SELECT @c_Status = ISNULL(RTRIM([Description]), '') 
         FROM [dbo].[Codelkup] WITH (NOLOCK) 
         WHERE ListName = 'ORDRSTATUS' 
         AND Code = @c_Status 
         AND StorerKey = @c_StorerKey 
      END
      ELSE IF EXISTS ( SELECT 1 FROM dbo.[Codelkup] WITH (NOLOCK) 
         WHERE ListName = 'ORDRSTATUS' AND Code = @c_Status AND StorerKey = '' )
      BEGIN
         SELECT @c_Status = ISNULL(RTRIM([Description]), '') 
         FROM [dbo].[Codelkup] WITH (NOLOCK) 
         WHERE ListName = 'ORDRSTATUS' 
         AND Code = @c_Status 
         AND StorerKey = ''
      END
   END

   SET @c_OrderInfoJson = (
                              SELECT 
                                 @c_Orderkey          [SO]
                                ,@c_ExternOrderkey    [ExternSO]
                                ,@c_SOStatus          [SOStatus]
                                ,@c_ShipperKey        [ShipperKey]
                                ,@c_SalesMan          [Platform]
                                ,@c_UserDefine03      [Store]
                                ,@c_Status            [Status]
                                ,@c_M_Company         [M_Company]
                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                          )

QUIT_SP:     
END -- procedure 
GO