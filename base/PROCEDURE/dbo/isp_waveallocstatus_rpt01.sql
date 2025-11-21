SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_waveallocstatus_rpt01                               */  
/* Creation Date: 23-MAR-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-12476-[CN] Porsche_Wave Short Allocation_RCMReport      */  
/*        :                                                             */  
/* Called By: r_dw_wave_alloc_status_rpt_01                             */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[isp_waveallocstatus_rpt01] 
         @c_Wavekey        NVARCHAR(10)
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT 
         , @c_Pickslipno      NVARCHAR(10)  
         , @c_PTZ             NVARCHAR(10)

         , @c_GetPickslipno   NVARCHAR(10)
         , @c_LPutawayZone    NVARCHAR(10)
         , @c_WaveType        NVARCHAR(18)
         , @n_OrderkeyCnt     INT
         , @c_Areakey         NVARCHAR(10)
         , @c_PPutawayZone    NVARCHAR(10)
         , @c_TodayDate       NVARCHAR(20)
         , @dt_AddDate        DATETIME
         , @n_CountSKU        INT
         , @n_CountUnits      INT 
         , @n_AvailableQty    INT = 0

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  

   CREATE TABLE #WavAllocStatusRpt01(
   Storerkey        NVARCHAR(20),
   Orderkey         NVARCHAR(10),
   ExtOrderKey      NVARCHAR(50),
   OHStatus         NVARCHAR(10),
   OpenQty          INT,
   qtyallocated     INT,
   originalqty      INT,
   SKU              NVARCHAR(20),
   WaveKey          NVARCHAR(10),
   MaxQty           INT,
   SafetyStock      INT, 
   AvailableQty     INT,
   Result           NVARCHAR(150) )

   SELECT @n_AvailableQty = sum(lli.QTY-lli.qtyallocated-lli.qtypicked)
   FROM WAVEDETAIL WITH (NOLOCK)  
   JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERDETAIL.Orderkey = WAVEDETAIL.Orderkey)
   JOIN ORDERS WITH (NOLOCK) ON  ( ORDERDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN LOTxLOCxID lli WITH (NOLOCK) ON LLI.sku = ORDERDETAIL.sku and lli.storerkey = ORDERDETAIL.storerkey
   JOIN LOC L WITH (NOLOCK) ON L.loc = lli.loc
   WHERE  ( WAVEDETAIL.Wavekey = @c_Wavekey )
   AND L.locationflag = 'NONE' 

   INSERT INTO  #WavAllocStatusRpt01 (Storerkey,Orderkey,ExtOrderkey,OHStatus,Wavekey,originalqty,SKU,Openqty,MaxQty,
                                      SafetyStock,qtyallocated,AvailableQty,result)
     SELECT DISTINCT 
         ORDERS.StorerKey,   
         ORDERS.OrderKey,   
         ORDERS.ExternOrderKey,   
         ORDERS.Status,   
         WAVEDETAIL.Wavekey,
         ORDERDETAIL.Originalqty,  
         ORDERDETAIL.Sku,
         ORDERDETAIL.OpenQty,
         CASE WHEN ISNUMERIC(SKU.BUSR9) = 1 THEN CAST(isnull(SKU.BUSR9,'99999') AS INT) ELSE 0 END,
         CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN CAST(isnull(SKU.BUSR5,'0') AS INT) ELSE 0 END, 
         ORDERDETAIL.QtyAllocated,
         @n_AvailableQty,        
       --CASE C.udf01 in ('0','2','3','5','9') THEN C.notes 
       -- WHEN C.udf01 = '1' AND ISNUMERIC(SKU.BUSR9) = 1 AND CAST(SKU.BUSR9 as INT) = C.udf02 
       --      AND ISNUMERIC(SKU.BUSR5) = 1 AND CAST(SKU.BUSR5 as int) > 0 AND ISNULL(C.udf03,'') = '' THEN C.notes
   --       CASE WHEN C.udf01 = '1' AND ISNUMERIC(SKU.BUSR9) = 1 AND CAST(SKU.BUSR9 as INT) <> C.udf02 
       --      AND ISNUMERIC(SKU.BUSR5) = 1 AND CAST(SKU.BUSR5 as int) > 0 AND ISNULL(C.udf02,'') = '' THEN C.notes
        CASE WHEN ORDERS.Status='0'  THEN (SELECT isnull(notes,'') FROM codelkup WITH (NOLOCK) WHERE listname='ALL_RESULT' and udf01='0')
        WHEN ORDERS.Status='2' THEN (SELECT isnull(notes,'') FROM codelkup WITH (NOLOCK) WHERE listname='ALL_RESULT' and udf01='2')
        WHEN ORDERS.Status='3' THEN (SELECT isnull(notes,'') FROM codelkup WITH (NOLOCK) WHERE listname='ALL_RESULT' and udf01='3')
        WHEN ORDERS.Status='5' THEN (SELECT isnull(notes,'') FROM codelkup WITH (NOLOCK) WHERE listname='ALL_RESULT' and udf01='5')
        WHEN ORDERS.Status='9' THEN (SELECT isnull(notes,'') FROM codelkup WITH (NOLOCK) WHERE listname='ALL_RESULT' and udf01='9')
        WHEN ORDERS.status='1' THEN (SELECT isnull(notes,'') FROM codelkup WITH (NOLOCK) WHERE listname='ALL_RESULT' and udf01='1' 
                                   and UDF02=(CASE WHEN isnull(sku.BUSR9,'99999')='99999' THEN '99999' ELSE '' END ) 
                                   and udf03=(CASE WHEN isnull(sku.BUSR5,'0')='0' THEN '0' ELSE '' END ))
          END as 'result'
   FROM WAVEDETAIL WITH (NOLOCK)  
   JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERDETAIL.Orderkey = WAVEDETAIL.Orderkey)
   JOIN ORDERS WITH (NOLOCK) ON  ( ORDERDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN SKU WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.StorerKey )    
                        AND   ( SKU.Sku = ORDERDETAIL.Sku) 
    --LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'ALL_RESULT' AND C.udf01 = ORDERS.Status AND C.Storerkey = ORDERS.StorerKey
   WHERE  ( WAVEDETAIL.Wavekey = @c_Wavekey )
   


   SELECT * FROM #WavAllocStatusRpt01 ORDER BY Orderkey, sku

END -- procedure  

GO