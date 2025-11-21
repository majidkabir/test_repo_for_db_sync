SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* StoredProc: isp_print_wave_composite_02                              */
/* Creation Date: 28-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-9998 - [PH] Unilever Wave Composite Report              */
/*        :                                                             */
/* Called By: r_dw_print_wave_composite_02                              */
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
CREATE PROC [dbo].[isp_print_wave_composite_02]
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
   
   SELECT	LOADPLANDETAIL.Loadkey,
			   ISNULL(C.short,'Y')  AS 'SHOWRPT',
            CASE WHEN ISNULL(CL.Code,'') <> '' THEN 'Y' ELSE 'N' END AS 'ShowSubReport',
            ISNULL(CL1.short,'Y')  AS 'SORTBYCALLTIME',
            ISNULL(CL2.short,'Y')  AS 'ShowSortListRpt',
            ISNULL(CL3.short,'Y')  AS 'ShowPickListRpt',
            ISNULL(CL4.short,'Y')  AS 'ShowLoadSheetRpt'
   FROM WAVEDETAIL     WITH (NOLOCK)
   JOIN ORDERS         WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey) 
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY)
   JOIN LOADPLAN       WITH (NOLOCK) ON (LOADPLANDETAIL.LOADKEY = LOADPLAN.LOADKEY)
   LEFT JOIN BOOKING_OUT WITH (NOLOCK) ON (BOOKING_OUT.BOOKINGNO = LOADPLAN.BOOKINGNO) 
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.storerkey= ORDERS.Storerkey               
                 AND listname = 'REPORTCFG' and code ='SHOWRPT'                            
   	           AND long='r_dw_print_wave_composite_02' 
                 AND C.code2=ORDERS.Facility
   LEFT JOIN CODELKUP CL WITH (nolock) ON CL.storerkey= ORDERS.Storerkey               
                 AND CL.listname = 'REPORTCFG' and CL.code ='ShowSubReport'                            
   	           AND CL.long='r_dw_print_wave_composite_02'
   LEFT JOIN CODELKUP CL1 WITH (nolock) ON CL1.storerkey= ORDERS.Storerkey               
                 AND CL1.listname = 'REPORTCFG' and CL1.code ='SORTBYCALLTIME'                            
   	            AND CL1.long='r_dw_print_wave_composite_02'
   LEFT JOIN CODELKUP CL2 WITH (nolock) ON CL2.storerkey= ORDERS.Storerkey               
                 AND CL2.listname = 'REPORTCFG' and CL2.code ='SHOWSORTLISTRPT'                            
   	           AND CL2.long='r_dw_print_wave_composite_02'
   LEFT JOIN CODELKUP CL3 WITH (nolock) ON CL3.storerkey= ORDERS.Storerkey               
                 AND CL3.listname = 'REPORTCFG' and CL3.code ='SHOWPICKLISTRPT'                            
   	           AND CL3.long='r_dw_print_wave_composite_02'
   LEFT JOIN CODELKUP CL4 WITH (nolock) ON CL4.storerkey= ORDERS.Storerkey               
                 AND CL4.listname = 'REPORTCFG' and CL4.code ='SHOWLOADSHEETRPT'                            
   	           AND CL4.long='r_dw_print_wave_composite_02'
   WHERE WAVEDETAIL.Wavekey = LEFT(@c_wavekey,10)
   GROUP BY LOADPLANDETAIL.Loadkey,
            ISNULL(C.short,'Y') ,
            ISNULL(CL.Code,''),
            ISNULL(CL1.short,'Y'),
            WAVEDETAIL.WAVEKEY,
            BOOKING_OUT.BOOKINGDATE,
            ISNULL(BOOKING_OUT.CALLTIME,''),
            ISNULL(LOADPLAN.BookingNo,''),
            ISNULL(CL2.short,'Y'),
            ISNULL(CL3.short,'Y'),
            ISNULL(CL4.short,'Y')     
   ORDER BY
   --FIRST CONDITION - SORT BY CALLTIME
   (CASE WHEN ISNULL(BOOKING_OUT.CALLTIME,'') ='' AND ISNULL(CL1.short,'Y')='Y' THEN ISNULL(LOADPLAN.BookingNo,'') END),
   (CASE WHEN ISNULL(BOOKING_OUT.CALLTIME,'') = '' AND ISNULL(CL1.short,'Y')='Y' THEN LOADPLANDETAIL.LoadKey END),
   
   --SECOND CONDITION - SORT BY LOADKEY
   (CASE WHEN ISNULL(BOOKING_OUT.CALLTIME,'') ='' AND ISNULL(LOADPLAN.BookingNo,'')='' AND ISNULL(CL1.short,'Y')='Y' THEN LOADPLANDETAIL.LOADKEY END),
   
   --NO CONDITION MET
   (CASE WHEN ISNULL(CL1.short,'Y')='Y' THEN ISNULL(BOOKING_OUT.CALLTIME,'') END),
   (CASE WHEN ISNULL(CL1.short,'Y')='Y' THEN ISNULL(LOADPLAN.BookingNo,'') END),
    LOADPLANDETAIL.LOADKEY 
   
END


GO