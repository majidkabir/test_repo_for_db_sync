SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPickSlipWave_39_3                                */
/* Creation Date:  04-Jul-2022                                          */
/* Copyright: LF Logistics                                              */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose:WMS-20052  [TW]HHT-Wave Pickslip_CR                          */
/*        :                                                             */
/* Called By: r_dw_print_wave_pickslip_39_3                             */
/*          : Call SP instead select statement in datawindow            */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 04-Jul-2022 CHONGCS  1.0  Devops Scripts Combine                     */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipWave_39_3]
           @c_WaveKey   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT

   SELECT ORDERS.Route, 
      Wave.AddDate, 
      WAVE.WaveKey, 
      PICKDETAIL.LOC, 
      PICKDETAIL.SKU,  
      SKU.DESCR,  
      PACK.CaseCnt, 
      PICKDETAIL.Qty, 
      LOC.LogicalLocation,
      LOTATTRIBUTE.Lottable02, 
      CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN 
               ISNULL(SKU.RetailSku,'')
      ELSE '' END AS RetailSku,
      convert(nvarchar(10),LOTATTRIBUTE.Lottable04,126)  AS Lottable04                     
   FROM ORDERS (NOLOCK)  
   JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey 
   JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC 
   JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey 
   JOIN WAVE (NOLOCK) ON WAVE.WaveKey = WAVEDETAIL.WaveKey 
   JOIN SKU (NOLOCK) ON SKU.StorerKey = PICKDETAIL.StorerKey AND SKU.SKU = PICKDETAIL.SKU 
   JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey 
   JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME='LOCCASHOW' AND C.Storerkey=ORDERS.storerkey--AND C.code=LOC.LocationCategory
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME='REPORTCFG' AND C1.Long='r_dw_print_wave_pickslip_39' 
                                       AND C1.Code='SHOWPICKLOC' AND c1.Storerkey=ORDERS.storerkey
                              AND  C1.short=ORDERS.stop                                    
   LEFT JOIN v_storerconfig2 SC WITH (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'DELNOTE06_RSKU'  
   WHERE WAVE.WaveKey = @c_WaveKey   
   AND 1 = CASE WHEN ISNULL(C1.short,'') <> '' AND ISNULL(C.code,'') <> '' 
                     AND C.code=LOC.LocationCategory AND LOC.LocLevel>CONVERT(INT,C.UDF02) THEN 1  
                WHEN ISNULL(C1.short,'N') = 'N'THEN 1 ELSE 0 END
   ORDER BY  LOC.LogicalLocation,PICKDETAIL.LOC, 
      PICKDETAIL.SKU, LOTATTRIBUTE.Lottable02 ,convert(nvarchar(10),LOTATTRIBUTE.Lottable04,126) 


 
END -- procedure

GO