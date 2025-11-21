SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_GetWaveSummary04                                    */  
/* Creation Date: 04-JUL-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Chooi                                                    */  
/*                                                                      */  
/* Purpose: WMS-9660 - KR_Nike_Picking List Summary Report              */  
/*        :                                                             */  
/* Called By: r_dw_wave_summary_04                                      */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 06-OCT-2020 CSCHONG  1.1   WMS-15313 revised report logic (CS01)     */
/************************************************************************/  
CREATE PROC [dbo].[isp_GetWaveSummary04] 
         @c_Wavekey        NVARCHAR(10),
         @c_Type           NVARCHAR(10) = ''  
  
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

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  

   CREATE TABLE #PTZ(
   Pickslipno       NVARCHAR(10),
   Areakey          NVARCHAR(10),
   Putawayzone      NVARCHAR(10),
   CountSKU         INT,
   CountUnits       INT )

   CREATE TABLE #Result(
   Pickslipno       NVARCHAR(10),
   LPutawayZone     NVARCHAR(10),
   WaveType         NVARCHAR(18),
   WaveKey          NVARCHAR(10),
   OrderkeyCnt      INT,
   Areakey          NVARCHAR(10),
   PPutawayZone     NVARCHAR(10),
   TodayDate        NVARCHAR(20),
   AddDate          DATETIME,
   CountSKU         INT,
   CountUnits       INT,
   PTZ              NVARCHAR(10),
   CountSKUPerPS    INT, 
   CountUnitsPerSKU INT )

   SELECT   @c_WaveType  = WaveType
          , @c_TodayDate = CONVERT(CHAR(16), GetDate(), 120)
          , @dt_AddDate  = AddDate
   FROM WAVE (NOLOCK) 
   WHERE Wavekey = @c_Wavekey
   
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PD.Pickslipno
   FROM PICKDETAIL PD (NOLOCK)
   WHERE PD.WAVEKEY = @c_Wavekey
   ORDER BY PD.Pickslipno

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Pickslipno

   WHILE @@FETCH_STATUS <> -1
   BEGIN 
   INSERT INTO #PTZ
      SELECT @c_Pickslipno, AD.Areakey, PTZ.Putawayzone, 0, 0
      FROM PUTAWAYZONE PTZ (NOLOCK)
      JOIN AreaDetail AD (NOLOCK) ON PTZ.PutawayZone = AD.PutawayZone
      WHERE PTZ.Facility = 'NKKR2'
      ORDER BY AD.Areakey, PTZ.Putawayzone

      FETCH NEXT FROM CUR_LOOP INTO @c_Pickslipno
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   --SELECT * FROM #PTZ

   INSERT INTO #Result
   SELECT Pickslipno, Putawayzone, @c_WaveType, @c_Wavekey, 0, Areakey, Putawayzone, @c_TodayDate, @dt_AddDate, 0, 0, '', 0, 0
   FROM #PTZ

   --SELECT * FROM #Result
   
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  PD.Pickslipno
         , L.PutawayZone
         , COUNT(PD.Orderkey) AS OrderkeyCnt
         , AD.Areakey 
         , PTZ.PutawayZone
         , COUNT(DISTINCT PD.SKU) AS CountSKU
         , SUM(PD.Qty) AS CountUnits
   FROM WAVE W (NOLOCK) 
   JOIN WAVEDETAIL WD (NOLOCK) ON W.WaveKey = WD.WaveKey
   JOIN PICKDETAIL PD (NOLOCK) ON WD.OrderKey = PD.OrderKey
   JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
   LEFT JOIN PutawayZone PTZ (NOLOCK) ON L.PutawayZone = PTZ.PutawayZone AND PTZ.Facility = 'NKKR2'
   LEFT JOIN AreaDetail AD (NOLOCK) ON PTZ.PutawayZone = AD.PutawayZone
   WHERE WD.WaveKey = @c_Wavekey
   GROUP BY PD.Pickslipno
          , L.PutawayZone
          , AD.Areakey 
          , PTZ.PutawayZone

   OPEN CUR_RESULT

   FETCH NEXT FROM CUR_RESULT INTO   @c_GetPickslipno
                                   , @c_LPutawayZone     
                                   , @n_OrderkeyCnt  
                                   , @c_Areakey      
                                   , @c_PPutawayZone     
                                   , @n_CountSKU     
                                   , @n_CountUnits   

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --For header, count the number of orderkey in 1 pickslipno 
      UPDATE #Result
      SET OrderkeyCnt = @n_OrderkeyCnt
      WHERE Pickslipno = @c_GetPickslipno

      --For detail, show in every page
      UPDATE #Result
      SET countSKU = @n_CountSKU, CountUnits = @n_CountUnits
      WHERE LPutawayZone = @c_LPutawayZone AND Areakey = @c_Areakey

      --For header, 1 pickslipno 1 putawayzone
      UPDATE #Result
      SET PTZ           =  @c_LPutawayZone ,
          CountSKUPerPS =  @n_CountSKU,
          CountUnitsPerSKU = @n_CountUnits
      WHERE Pickslipno = @c_GetPickslipno AND WaveKey = @c_Wavekey
      
      FETCH NEXT FROM CUR_RESULT INTO   @c_GetPickslipno
                                      , @c_LPutawayZone    
                                      , @n_OrderkeyCnt  
                                      , @c_Areakey      
                                      , @c_PPutawayZone      
                                      , @n_CountSKU     
                                      , @n_CountUnits   
   END                                
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT

   SELECT * FROM #Result 
   WHERE countsku<> 0 AND CountUnits <> 0             --CS01
   ORDER BY Pickslipno, Areakey, LPutawayZone

END -- procedure  

GO