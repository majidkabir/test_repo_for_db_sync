SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store Procedure:  isp_ConsoPickList45                                */    
/* Creation Date:  13-Aug-2020                                          */    
/* Copyright: IDS                                                       */    
/* Written by:  CSCHONG                                                 */    
/*                                                                      */    
/* Purpose: WMS-14680. [KR] Allbirds_PickSlip Report_datawindow_NEW     */    
/*                                                                      */    
/* Input Parameters:  @c_Loadkey  - (LoadKey)                           */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  Report                                               */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By:  r_dw_consolidated_pick45                                 */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/************************************************************************/    
    
CREATE PROC [dbo].[isp_ConsoPickList45]  
            (@c_LoadKey NVARCHAR(10)
            ,@c_type   NVARCHAR(10)='H')    
AS    
BEGIN  
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_StartTranCnt   INT    
         , @n_continue       INT  
         , @n_err            INT   
         , @b_Success        INT  
         , @c_errmsg         NVARCHAR(255)  
         , @c_PickHeaderKey  NVARCHAR(10)  
         , @c_PrintedFlag    NVARCHAR(1)  
  
   SET @n_StartTranCnt  = @@TRANCOUNT    
   SET @n_Continue      = 1   
   SET @n_err           = 0  
   SET @b_Success       = 1  
   SET @c_errmsg        = ''  
   SET @c_PickHeaderKey = ''  
   SET @c_PrintedFlag   = 'N'  
  
  CREATE TABLE #TEMP_ConsoPackList45  
         (  Rowid            INT IDENTITY(1,1), 
            loadkey          NVARCHAR(20) NULL, 
            LoadType         NVARCHAR(20) NULL,  
            Pickslipno       NVARCHAR(20) NULL,  
            TaskBatchNo      NVARCHAR(10) NULL,  
            DevPosition      NVARCHAR(10) NULL,   
            ORDERKEY         NVARCHAR(20) NULL,  
            LOC              NVARCHAR(10) NULL,  
            SKU              NVARCHAR(20) NULL,  
            ID               NVARCHAR(18) NULL,  
            SSTYLE           NVARCHAR(20) NULL,  
            SSIZE            NVARCHAR(10) NULL, 
            QTY              INT)     


 /* Start Modification */   
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order    
  
   IF NOT EXISTS(  
                 SELECT PickHeaderKey  
                 FROM   PICKHEADER WITH (NOLOCK)  
                 WHERE  ExternOrderKey = @c_LoadKey  
                 AND    Zone = '7'  
                )  
   BEGIN  
      SET @b_success = 0   
  
      EXECUTE nspg_GetKey   
            'PICKSLIP'  
          , 9  
          , @c_PickHeaderKey  OUTPUT  
          , @b_success        OUTPUT  
          , @n_err            OUTPUT  
          , @c_errmsg         OUTPUT    
  
      IF @b_success<>1  
      BEGIN  
         SET @n_continue = 3  
         GOTO QUIT  
      END    
          
      SET @c_PickHeaderKey = 'P'+@c_PickHeaderKey    
  
      INSERT INTO PICKHEADER  
        (PickHeaderKey ,ExternOrderKey,PickType,Zone)  
      VALUES  
        (@c_PickHeaderKey,@c_Loadkey,'1','7')    
  
      SET @n_err = @@ERROR    
  
      IF @n_err<>0  
      BEGIN  
         SET @n_continue = 3             SET @n_err = 63501    
         SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                       + ': Insert Into PICKHEADER Failed. (isp_ConsoPickList30)'  
         GOTO QUIT  
      END  
   END  
   ELSE  
   BEGIN  
      SELECT @c_PickHeaderKey = PickHeaderKey  
      FROM   PickHeader WITH (NOLOCK)  
      WHERE  ExternOrderKey = @c_Loadkey  
      AND    Zone = '7'  
  
   END    
  
   IF ISNULL(RTRIM(@c_PickHeaderKey) ,'')=''  
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 63502    
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)   
                   + ': Get LoadKey Failed. (isp_ConsoPickList30)'  
      GOTO QUIT  
   END    
      
   INSERT INTO #TEMP_ConsoPackList45(loadkey,LoadType,Pickslipno,TaskBatchNo,DevPosition,ORDERKEY,LOC,SKU,ID,SSTYLE,SSIZE,qty)
   SELECT DISTINCT  L.LOADKEY,CASE WHEN l.UserDefine04 = 'AB_MULTI' THEN 'M' ELSE 'S' END, PH.PickHeaderKey, PT.TaskBatchNo, PT.DevicePosition, 
                    LPD.ORDERKEY, PD.LOC, PD.SKU, PD.ID, S.style, s.size, PD.QTY
   FROM Loadplan L WITH (NOLOCK)
   LEFT JOIN Pickheader PH WITH (NOLOCK) ON L.Loadkey = PH.ExternOrderkey
   LEFT JOIN LoadplanDetail LPD WITH (NOLOCK) ON L.Loadkey = LPD.Loadkey
   LEFT JOIN PackTask PT WITH (NOLOCK) ON PT.Orderkey = LPD.Orderkey
   LEFT JOIN PickDetail PD WITH (NOLOCK) ON PD.Orderkey = LPD.Orderkey
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU 
   WHERE L.LOADKEY = @c_LoadKey
   ORDER BY L.LOADKEY,CASE WHEN l.UserDefine04 = 'AB_MULTI' THEN 'M' ELSE 'S' END, PH.PickHeaderKey,PT.TaskBatchNo, PT.DevicePosition, 
            LPD.ORDERKEY, PD.LOC, PD.SKU, PD.ID


   IF @c_type = 'H' GOTO TYPE_H     
   IF @c_type = 'M' GOTO TYPE_M  
   IF @c_type = 'S' GOTO TYPE_S  
  

 TYPE_H:

  SELECT DISTINCT loadkey as loadkey ,LoadType as loadtype
  FROM #TEMP_ConsoPackList45
  WHERE loadkey = @c_LoadKey

  GOTO QUIT

 TYPE_M:

 SELECT  Pickslipno as pickslipno,TaskBatchNo as TaskBatchNo,
         DevPosition as DevPosition,LoadType as loadtype,LOC as LOC,ID as ID ,ORDERKEY as Orderkey,SSTYLE as SSTYLE,
         SKU as SKU,qty as Qty ,loadkey as loadkey ,
         SSIZE as SSIZE
  FROM #TEMP_ConsoPackList45
  WHERE loadkey = @c_LoadKey
  AND LoadType = 'M'
  ORDER BY loadkey,pickslipno,TaskBatchNo,DevPosition,LOC,ORDERKEY,SKU

  GOTO QUIT


 TYPE_S:

 SELECT Pickslipno as pickslipno,LoadType as loadtype,LOC as LOC,ID as ID ,ORDERKEY as Orderkey,SSTYLE as SSTYLE,
         SKU as SKU,qty as Qty ,loadkey as loadkey ,
         SSIZE as SSIZE
  FROM #TEMP_ConsoPackList45
  WHERE loadkey = @c_LoadKey
  AND LoadType = 'S'
  ORDER BY loadkey,pickslipno,LOC,SKU

  GOTO QUIT

   QUIT:  
   IF @n_continue=3 -- Error Occured - Process And Return  
   BEGIN  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ConsoPickList45'   
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012   
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1    
      WHILE @@TRANCOUNT>@n_StartTranCnt  
      BEGIN  
         COMMIT TRAN  
      END   
      RETURN  
   END  
END /* main procedure */    

GO