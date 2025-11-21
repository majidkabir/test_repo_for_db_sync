SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* StoredProc: isp_print_wave_composite_03                              */
/* Creation Date: 17-JUN-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-17241 THGSG - Pickslip Details in Picking Summary Report*/
/*        :                                                             */
/* Called By: r_dw_print_wave_composite_03                              */
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
CREATE PROC [dbo].[isp_print_wave_composite_03]
            @c_wavekey     NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT = 1  

   SET @n_StartTCnt = @@TRANCOUNT
   
   SELECT   LOADPLANDETAIL.Loadkey,
            WAVEDETAIL.WaveKey, 
            PID.CaseID  
   FROM WAVEDETAIL     WITH (NOLOCK)
   JOIN ORDERS         WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey) 
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY)
   JOIN LOADPLAN       WITH (NOLOCK) ON (LOADPLANDETAIL.LOADKEY = LOADPLAN.LOADKEY)
   JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.Orderkey = ORDERS.Orderkey  
   WHERE WAVEDETAIL.Wavekey = LEFT(@c_wavekey,10)
   GROUP BY LOADPLANDETAIL.Loadkey,
            WAVEDETAIL.WaveKey, PID.CaseID  
   ORDER BY
    WAVEDETAIL.WaveKey ,
    LOADPLANDETAIL.LOADKEY , PID.CaseID 
   
END


GO