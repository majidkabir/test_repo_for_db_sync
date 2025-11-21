SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetWaveSummary02                                    */
/* Creation Date: 29-JAN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3053 - PH Picklist Barcode Summary Report               */
/*        :                                                             */
/* Called By: r_dw_wave_summary02                                       */
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
CREATE PROC [dbo].[isp_GetWaveSummary02]
           @c_Wavekey         NVARCHAR(10)
        ,  @c_RptCopy         NVARCHAR(30)

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

   SELECT DISTINCT 
          WD.Wavekey
         ,LPD.Loadkey
         ,RptCopy = @c_RptCopy
   FROM WAVEDETAIL     WD  WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey
   ORDER BY LPD.Loadkey
  
END -- procedure

GO