SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Proc: isp_GetWaveSummary05                                    */    
/* Creation Date: 21-Dec-2021                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-18585 - NIKESGEC - Picking Summary Report               */    
/*                                                                      */    
/* Called By: r_dw_wave_summary05                                       */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date           Author   Ver   Purposes                               */   
/* 21-Dec-2021    WLChooi  1.0   DevOps Combine Script                  */
/************************************************************************/    
CREATE PROC [dbo].[isp_GetWaveSummary05] 
         @c_WaveKey     NVARCHAR(10)
       , @c_Type        NVARCHAR(10) = 'D'
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_StartTCnt       INT    
         , @n_Continue        INT  

   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue = 1  

   IF @c_Type = 'H'
   BEGIN
      SELECT WAVE.WaveKey
      FROM WAVE (NOLOCK)
      WHERE WaveKey = @c_WaveKey
   END
   ELSE
   BEGIN
      SELECT WD.WaveKey
           , SUBSTRING(TRIM(L.PutawayZone),1,2) AS PZonePrefix
           , TRIM(L.Putawayzone) AS PZone
           , TRIM(ISNULL(OH.OrderGroup,'')) AS OrderGroup
           , ISNULL(PD.PickSlipNo,'') AS PickSlipNo
           , SUM(PD.Qty) AS Qty
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
      JOIN LOC L (NOLOCK) ON L.LOC = PD.LOC
      WHERE WD.WaveKey = @c_WaveKey
      GROUP BY WD.WaveKey
             , SUBSTRING(TRIM(L.PutawayZone),1,2)
             , TRIM(L.Putawayzone)
             , TRIM(ISNULL(OH.OrderGroup,''))
             , ISNULL(PD.PickSlipNo,'')
      ORDER BY WD.WaveKey
             , SUBSTRING(TRIM(L.PutawayZone),1,2)
             , TRIM(L.Putawayzone)
             , TRIM(ISNULL(OH.OrderGroup,''))
             , ISNULL(PD.PickSlipNo,'')
      
   END
END -- procedure 

GO