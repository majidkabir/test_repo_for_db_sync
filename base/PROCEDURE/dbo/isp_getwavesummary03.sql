SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Proc: isp_GetWaveSummary03                                    */    
/* Creation Date: 03-APR-2019                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: WMS-8408 - NIKE PH - Wave Summary Report                    */    
/*        :                                                             */    
/* Called By: r_dw_wave_summary03                                       */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date					Author   Ver   Purposes                         */   
/************************************************************************/    
CREATE PROC [dbo].[isp_GetWaveSummary03] 
         @c_waveKey        NVARCHAR(20)    
      ,  @c_type           NVARCHAR(10) = 'H'    
    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE      
           @n_StartTCnt       INT    
         , @n_Continue        INT  
		 , @n_CntStatus       INT   
    
    
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue = 1  
   SET @n_CntStatus = 0
   


   CREATE TABLE #TEMPWS03H
	( wavekey          NVARCHAR(10),
	  OHFacility       NVARCHAR(10),
	  WVDate           DATETIME,
	  storerkey        NVARCHAR(20),
	  Deliverydate     DATETIME,	  
	  TTLORD           INT,
	  TTLLOAD          INT,
	  TTLSKU           INT,
	  REPLNSTATUS      NVARCHAR(50),
	  ShowCS           INT
	)

  CREATE TABLE #TEMPWS03REPFROM
	( wavekey     NVARCHAR(10),
	  PutawayZone NVARCHAR(10),
	  CNTUCC      INT)

	CREATE TABLE #TEMPWS03REPTO
	( wavekey        NVARCHAR(10),
	  PutawayZone    NVARCHAR(10),
	  LocationType   NVARCHAR(10),
	  LocDesc        NVARCHAR(250),
	  CNTUCC         INT)

	  
	CREATE TABLE #TEMPWS03P
	( wavekey     NVARCHAR(10),
	  PZone       NVARCHAR(10),
	  Loctype     NVARCHAR(10),
	  CNTSKU      INT,
	  PDQTY       INT)


  CREATE TABLE #TEMPWSCS
	( STORERKEY   NVARCHAR(10),
	  AREAKEY     NVARCHAR(10),
	  wavekey     NVARCHAR(10),
	  FROMLOC     NVARCHAR(10),
	  FROMID      NVARCHAR(18),
	  TOLOC       NVARCHAR(10))

	INSERT INTO #TEMPWS03H(wavekey,OHFacility,WVDate,storerkey,Deliverydate,TTLORD,TTLLOAD,TTLSKU,REPLNSTATUS,ShowCS)
	SELECT DISTINCT WV.WaveKey,MIN(OH.Facility) as OHFacility,MIN(WV.AddDate) as WVDate,
	  MIN(OH.Storerkey) as Storerkey,MIN(OH.deliverydate) as Deliverydate,
	  COUNT(distinct OH.OrderKey) as TTLORD,
	  COUNT(distinct OH.LoadKey) AS TTLLOAD,COUNT(distinct OD.Sku) AS TTLSKU,
	  CASE WHEN MIN(TD.status)>'0' THEN 'Replenishment Status Started' ELSE 'Replenishment Status Not Started' END
	  ,0
    FROM WAVE WV WITH  (NOLOCK)
	JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.wavekey = WV.Wavekey
	join taskdetail TD WITH (NOLOCK) ON TD.wavekey = WV.wavekey
	join orders OH WITH (NOLOCK) ON OH.Orderkey = WD.orderkey AND OH.storerkey = TD.storerkey
	JOIN Orderdetail OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
	where WV.wavekey=@c_wavekey
	and TaskType = 'RPF'
	group by WV.WaveKey

  
  INSERT INTO #TEMPWS03REPFROM (wavekey,PutawayZone,CNTUCC)
    
  SELECT WV.wavekey,l.putawayzone AS PutawayZone,count(DISTINCT td.caseid) as CNTUCC
	 FROM WAVE WV WITH  (NOLOCK)
	JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.wavekey = WV.Wavekey
	join taskdetail TD WITH (NOLOCK) ON TD.wavekey = WV.wavekey
	join LOC l with (nolock) on L.Loc = TD.FromLoc and l.LocationType = 'OTHER'
	where WV.wavekey=@c_wavekey 
	and TaskType = 'RPF'
	GROUP BY WV.wavekey,l.putawayzone
	ORDER BY WV.wavekey,l.putawayzone
  
  INSERT INTO #TEMPWS03REPTO (wavekey,PutawayZone,LocationType,LocDesc,CNTUCC)
    
     SELECT WV.wavekey,l.pickzone,l.LocationType,c.description,count(distinct UCC.UCCNO) as CNTUCC
	 FROM WAVE WV WITH  (NOLOCK)
	JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.wavekey = WV.Wavekey
	join taskdetail TD WITH (NOLOCK) ON TD.wavekey = WV.wavekey
	left join UCC WITH (NOLOCK) ON UCC.ID=TD.FROMID
	join LOC l with (nolock) on L.Loc = TD.ToLoc and (l.LocationType = 'DYNPPICK' OR l.LocationType ='DYNPICKP')
	LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='Loctype' and c.code=l.LocationType
	where WV.wavekey=@c_wavekey 
	and TaskType = 'RP1'
	GROUP BY WV.wavekey,l.pickzone,l.LocationType,c.description
    ORDER BY l.pickzone,c.description

  
  INSERT INTO #TEMPWS03P (wavekey,Pzone,Loctype,CNTSKU,PDQTY)    
  SELECT WV.wavekey,L.pickzone as PZone,L.locationtype AS LocType,
         count(distinct pd.sku) AS CNTSKU,sum(pd.qty) AS PDQTY
	FROM WAVE WV WITH  (NOLOCK) 
	JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.wavekey = WV.Wavekey
	--join taskdetail TD WITH (NOLOCK) ON TD.wavekey = WV.wavekey
	join orders OH WITH (NOLOCK) ON OH.Orderkey = WD.orderkey --AND OH.storerkey=TD.Storerkey
	join orderdetail OD WITH (NOLOCK) ON Od.orderkey = OH.orderkey
	JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OD.Orderkey and PD.orderlinenumber = OD.Orderlinenumber
	                                  AND PD.sku = od.sku
	join LOC l with (nolock) on L.Loc = PD.Loc
	where WV.wavekey=@c_wavekey
	group by WV.wavekey,L.pickzone,L.locationtype
	order by WV.wavekey,L.pickzone,L.locationtype
  
  INSERT INTO #TEMPWSCS (STORERKEY,AREAKEY,wavekey,FROMLOC,FROMID,TOLOC)    
  select distinct td.storerkey AS STORERKEY,ISNULL(td.areakey,'') AS AREAKEY,
              td.wavekey AS WAVEKEY,td.fromloc AS FROMLOC
              ,td.fromid AS FROMID,td.toloc AS TOLOC
	FROM WAVE WV WITH  (NOLOCK)
	JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.wavekey = WV.Wavekey
	join taskdetail TD WITH (NOLOCK) ON TD.wavekey = WV.wavekey
	join loc l WITH (NOLOCK) ON L.loc=td.toloc
	where WV.wavekey=@c_wavekey
	AND l.LocationCategory = 'PROC' 
    ORDER BY td.storerkey,ISNULL(td.areakey,''),td.wavekey,td.fromloc,td.fromid,td.toloc

	IF EXISTS (SELECT 1 FROM #TEMPWSCS WHERE wavekey=@c_waveKey)
	BEGIN
	  INSERT INTO #TEMPWS03H(wavekey,OHFacility,WVDate,storerkey,Deliverydate,TTLORD,TTLLOAD,TTLSKU,REPLNSTATUS,ShowCS)
	  SELECT TOP 1 wavekey,OHFacility,WVDate,storerkey,Deliverydate,TTLORD,TTLLOAD,TTLSKU,REPLNSTATUS,1
	  FROM #TEMPWS03H
	  WHERE wavekey = @c_waveKey
	END
  
     IF @c_type = 'H' GOTO TYPE_H
     IF @c_type = 'RF' GOTO TYPE_RF
	 IF @c_type = 'RT' GOTO TYPE_RT
	 IF @c_type = 'P' GOTO TYPE_P
	 IF @c_type = 'CS' GOTO TYPE_CS

  
   TYPE_H:  

	 SELECT * FROM #TEMPWS03H
     DROP TABLE #TEMPWS03H
     GOTO QUIT_SP;
    

   TYPE_RF:

	 SELECT * FROM #TEMPWS03REPFROM
	 ORDER BY wavekey,PutawayZone

     DROP TABLE #TEMPWS03REPFROM
     GOTO QUIT_SP;


	 
	  TYPE_RT: 

	 SELECT * FROM #TEMPWS03REPTO
	 ORDER BY PutawayZone,LocDesc

     DROP TABLE #TEMPWS03REPTO
     GOTO QUIT_SP;

  TYPE_P: 

	 SELECT * FROM #TEMPWS03P
	 ORDER BY wavekey,Pzone,Loctype

     DROP TABLE #TEMPWS03P
     GOTO QUIT_SP;
	
	 TYPE_CS: 

	 SELECT * FROM #TEMPWSCS
	 ORDER BY wavekey,AREAKEY

     DROP TABLE #TEMPWSCS
     GOTO QUIT_SP;

QUIT_SP:    
  

    
END -- procedure 

GO