SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Proc: [API].[isp_ECOMP_GetOrderInfo]                          */    
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
/* 24-FEB-2023 Wan02    1.1   PAC-4 NextGen Ecom Packing - Single       */    
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetOrderInfo]    
   @c_Orderkey    NVARCHAR(10)  
,  @c_SourceApp   NVARCHAR(10) = 'WMS' --Wan02, IF SCE, return result set may impact NextGen Ecom                
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE      
           @n_StartTCnt       INT            = @@TRANCOUNT    
         , @n_Continue        INT            = 1    
    
   SELECT TOP 1 ORDERS.Orderkey    
      ,ORDERS.ExternOrderkey    
      ,ORDERS.LoadKey    
      ,ORDERS.ConsigneeKey    
      ,ORDERS.ShipperKey    
      ,ORDERS.SalesMan    
      ,ORDERS.Route    
      ,ORDERS.UserDefine03    
      ,ORDERS.UserDefine04    
      ,ORDERS.UserDefine05    
      ,ORDERS.Status    
      ,ORDERS.SOStatus    
      ,TrackingNo = CASE WHEN SC.Configkey IS NOT NULL THEN ISNULL(RTRIM(ORDERS.TrackingNo),'') ELSE  --NJOW01    
                         CASE WHEN ISNULL(RTRIM(ORDERS.TrackingNo),'') <> '' THEN ORDERS.TrackingNo ELSE ISNULL(RTRIM(ORDERS.UserDefine04),'') END    
                    END         
      ,ISNULL(RTRIM(ORDERS.M_Company), '') As 'M_Company'
      --,TrackingNo = CASE WHEN ISNULL(RTRIM(TrackingNo),'') <> '' THEN TrackingNo ELSE ISNULL(RTRIM(UserDefine04),'') END    
   FROM ORDERS WITH (NOLOCK)    
   LEFT JOIN STORERCONFIG SC (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'EPACKGetTrackNoSkipUDF04' AND SC.Svalue = '1'  --NJOW01    
   WHERE ORDERS.Orderkey = @c_Orderkey    
    
QUIT_SP:     
END -- procedure 
GO