SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_wave_Label_56                       */
/* Creation Date: 7-Mar-2016                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  To print Ucc Carton Label 56                               */
/*                                                                      */
/* Input Parameters: Parm01,Parm02,Parm03,Parm04,Parm05                 */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_wave_label_56                            */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_wave_Label_56] (
         @c_wavekey NVARCHAR(10) 
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


  DECLARE  @c_storerkey      NVARCHAR(20)
        ,  @c_Pickslipno     NVARCHAR(20)
        ,  @c_labelno        NVARCHAR(20)
        ,  @c_RptType        NVARCHAR(10)
        ,  @c_cartonno       NVARCHAR(10)
        ,  @c_sku            NVARCHAR(20)
        ,  @c_getlabelno     NVARCHAR(20)   
        ,  @n_rowid          INT
        ,  @n_getrowid       INT
        ,  @n_CntRec         INT
        ,  @c_getOrdBuyerPO  NVARCHAR(20)   
        ,  @c_OrdLabelno     NVARCHAR(20)  
        ,  @c_logicalLoc     NVARCHAR(10)
        ,  @c_getLoc         NVARCHAR(10)
        ,  @c_GetLocAisle    NVARCHAR(10)
        ,  @n_CntLocAisle    INT
        ,  @n_getCntLocAisle INT
       
   --CS01a start
   DECLARE @c_Llabelno NVARCHAR(20)
          ,@c_label_content NVARCHAR(4000)   
          ,@c_Lsku NVARCHAR(20)  
          ,@n_Lqty INT
			 ,@c_Getlblcontent NVARCHAR(4000)   
			 
 --CS02 start
 DECLARE @c_Getprinter     NVARCHAR(10),
         @c_UserId         NVARCHAR(20),
         @c_GetDatawindow  NVARCHAR(40),
         @c_ReportID       NVARCHAR(10),
         @n_noofParm       INT,
         @b_success        int,
         @n_err            int,
         @c_errmsg         NVARCHAR(255)

                  			 


   SET @c_storerkey     = ''     
   SET @c_Pickslipno    = ''    
   SET @c_labelno       = ''  
   SET @c_RptType       = '0'
   
   --CS01a start
   SET @c_Llabelno=''
   SET @c_label_content=''
   SET @c_Lsku=''
   SET @n_Lqty=0
   
   SET @c_Getprinter = ''
   SET @c_ReportID='UCClbconso'
   SET @c_UserId= SUSER_NAME()
   SET @n_noofParm = 4
   SET @c_GetDatawindow  = 'r_dw_ucc_carton_label_56'
   
   SELECT @c_Getprinter = defaultprinter
   FROM RDT.RDTUser AS r WITH (NOLOCK)
   WHERE r.UserName = @c_UserId
   
   IF ISNULL(@c_Getprinter,'') = ''
   BEGIN
   	SET @c_Getprinter = 'PDF'
   END


   CREATE TABLE #TMP_GETCOLUMN (
          [RowID]    [INT] IDENTITY(1,1) NOT NULL,
          col01     NVARCHAR(20) NULL,
          col02     NVARCHAR(20) NULL,
          col03     NVARCHAR(20) NULL,
          col04     NVARCHAR(20) NULL,
          col05     NVARCHAR(30) NULL,
          Col06     NVARCHAR(30) NULL,
          col07     NVARCHAR(30) NULL)

   CREATE TABLE #TMP_WAVEPICK (
          [ID]    [INT] IDENTITY(1,1) NOT NULL, 
          Storerkey    NVARCHAR(20) NULL,
          Orderkey     NVARCHAR(20) NULL,
          Loadkey      NVARCHAR(20) NULL,
          wavekey      NVARCHAR(20) NULL,
          Pickslipno   NVARCHAR(20) NULL,
          Labelno      NVARCHAR(20) NULL,
          SKU          NVARCHAR(20) NULL,
          qty          INT NULL,
          CartonNo     INT,
          PickLoc      NVARCHAR(10) NULL,
          Rowno        INT,
          LocAisle     NVARCHAR(20) NULL)         
          
   CREATE TABLE #TMP_sortOutput
   (labelno NVARCHAR(20), 
    CntLocAisle INT ,
    LocAisle NVARCHAR(10),
    PicLoc   NVARCHAR(10) )      

	CREATE TABLE #TMP_DPP
	(CASEID NVARCHAR(20),
	LOC      NVARCHAR(10) )      

 INSERT INTO #TMP_WAVEPICK (Storerkey,Orderkey,Loadkey,wavekey,Pickslipno,Labelno,/*SKU,qty,*/CartonNo,PickLoc,rowno,LocAisle)
  SELECT DISTINCT ORD.Storerkey,ORD.ORDERKEY,ORD.LOADKEY,WVDET.WAVEKEY,PIDET.PICKSLIPNO
 ,PIDET.caseid,/*S.Sku,PIDET.qty,*/CL.SeqNo,MIN(td.logicaltoloc),0,''                          
  FROM wavedetail WVDET WITH (NOLOCK)
  JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = WVDET.ORDERKEY
  JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.ORDERKEY = ORD.ORDERKEY
  --JOIN PACKDETAIL PADET WITH (NOLOCK) ON PIDET.CaseId = PADET.Labelno
  LEFT JOIN TaskDetail AS td WITH (NOLOCK) ON td.TaskType='RPF' AND td.TaskDetailKey=pidet.TaskDetailKey
  LEFT JOIN loc l WITH (NOLOCK) ON l.loc = PIDET.Loc AND l.LocationType='DYNPPICK' AND l.Facility = ord.Facility
  LEFT JOIN CartonListDetail CLD WITH (NOLOCK) ON CLD.PickDetailKey=PIDET.PickDetailKey
  LEFT JOIN CartonList AS CL WITH (NOLOCK) ON CL.CartonKey = CLD.CartonKey
  --LEFT JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON lli.sku=pidet.Sku AND lli.Loc = pidet.Loc 
 -- JOIN PACKHEADER PAH WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
 JOIN SKU S (NOLOCK) ON PIDET.SKU = S.SKU AND PIDET.Storerkey = S.StorerKey
  WHERE WVDET.WaveKey = @c_wavekey
  AND PIDET.UOM in ('6','7')
  --AND ISNULL(PADET.Labelno,'') <> ''
 -- GROUP BY ORD.Storerkey,ORD.ORDERKEY,ORD.LOADKEY,WVDET.WAVEKEY,PIDET.PICKSLIPNO
 --,PADET.Labelno,PADET.SKU,PADET.CartonNo,ORD.UpdateSource
  GROUP BY ORD.Storerkey,ORD.ORDERKEY,ORD.LOADKEY,WVDET.WAVEKEY,PIDET.PICKSLIPNO
 ,PIDET.caseid,/*S.Sku,PIDET.qty,*/CL.SeqNo
  ORDER BY PIDET.caseid
  
  SELECT DISTINCT PD.CASEID AS CASEID, L.LOC AS LOC 
  INTO #T1
  FROM PickDetail PD WITH (NOLOCK) 
  JOIN SKUXLOC SL WITH (NOLOCK) ON PD.SKU=SL.SKU 
  INNER JOIN ORDERS O WITH (NOLOCK) ON　O.Orderkey=PD.Orderkey
  INNER JOIN LOC L WITH (NOLOCK) ON SL.LOC=L.LOC and L.Facility=O.Facility AND L.LOCATIONTYPE='DYNPPICK'
  INNER JOIN WAVEDETAIL WD WITH (NOLOCK) ON O.Orderkey=WD.Orderkey
  WHERE WD.WaveKey = @c_wavekey

  INSERT INTO #TMP_DPP SELECT CASEID, MIN(LOC) FROM #T1 GROUP BY CASEID

  --ELECT * FROM #TMP_WAVEPICK
  /*CS03 Start*/
  
  --SELECT  'start 1 ' , GETDATE()
  DECLARE CUR_logicalLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
     
  SELECT DISTINCT labelno,PickLoc
  FROM #TMP_WAVEPICK TP  (NOLOCK)
  --JOIN orders ord WITH (NOLOCK) ON ord.OrderKey=tp.orderkey
  GROUP BY labelno,PickLoc
  ORDER BY PickLoc
  
  OPEN CUR_logicalLoc

  FETCH NEXT FROM CUR_logicalLoc INTO @c_OrdLabelno,@c_logicalLoc
   WHILE @@FETCH_STATUS <> -1
   BEGIN  
   	SET @c_getloc = ''
   	SET @c_GetLocAisle = ''
   	
   	
   	
   	IF ISNULL(@c_logicalLoc,'') = ''
   	BEGIN
   		
   	--	SELECT  'start 1a ' , GETDATE()
   		
   		--SET @c_getloc='NoPickLOC'
		SELECT TOP 1 @c_getloc = L.Loc
		FROM    #TMP_DPP (NOLOCK) INNER JOIN LOC L (NOLOCK) ON #TMP_DPP.LOC=L.LOC
		WHERE #TMP_DPP.CASEID = @c_OrdLabelno
   		/*SELECT TOP 1 @c_getloc = lli.LOC
   		FROM PICKDETAIL PD WITH (NOLOCK)
   		JOIN ORDERS ORD WITH (NOLOCK) ON ORD.orderkey=PD.orderkey 
   		JOIN LOC L WITH (NOLOCK) ON l.loc = PD.loc AND l.locationtype='DYNPPICK' AND l.facility = ORD.facility
   		JOIN lotxlocxid lli WITH (NOLOCK) ON lli.loc=l.loc AND lli.lot = PD.lot 
   		                     AND lli.id = PD.id 
   		WHERE PD.caseid = @c_labelno
		*/
   	END
   	--SELECT  'end 1a ' , GETDATE()
   	
   	IF ISNULL(@c_logicalLoc,'') <> ''
   	BEGIN
   			
   	  SELECT @c_GetLocAisle = L.locAisle
   	  FROM loc L WITH (NOLOCK)
   	  WHERE L.loc = @c_logicalLoc 
   	END
   	ELSE IF ISNULL(@c_getloc,'') <> ''
   	BEGIN
   		SELECT @c_GetLocAisle = L.locAisle
   	  FROM loc L WITH (NOLOCK)
   	  WHERE L.loc = @c_getloc 
   	END	
   	
   	UPDATE #TMP_WAVEPICK
   	SET pickloc = CASE WHEN ISNULL(pickloc,'') = '' THEN @c_getLoc ELSE pickloc END
   	, LocAisle = @c_GetLocAisle
   	WHERE Labelno = @c_OrdLabelno
   	
   FETCH NEXT FROM CUR_logicalLoc INTO @c_OrdLabelno,@c_logicalLoc
	END 
	
	CLOSE CUR_logicalLoc
	DEALLOCATE CUR_logicalLoc
  
  /*CS03 End*/
  --SELECT  'End 1 ' , GETDATE()
  /*CS01a Start*/
  
  --SELECT * FROM #TMP_WAVEPICK
  
  --SELECT DISTINCT Labelno,MIN(LocAisle),MIN(PickLoc),COUNT(DISTINCT LocAisle) 
  --FROM #TMP_WAVEPICK            
  --GROUP BY Labelno,LocAisle
  --ORDER BY labelno,COUNT(DISTINCT LocAisle) ,MIN(PickLoc)
  
  DECLARE CUR_labelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
  SELECT DISTINCT Labelno,MIN(LocAisle),MIN(PickLoc),COUNT(DISTINCT LocAisle) 
  FROM #TMP_WAVEPICK            
  GROUP BY Labelno,LocAisle
  ORDER BY COUNT(DISTINCT LocAisle) ,MIN(PickLoc),labelno
  
  OPEN CUR_labelno

  FETCH NEXT FROM CUR_labelno INTO @c_Llabelno,@c_GetLocAisle,@c_logicalLoc,@n_CntLocAisle 
                                    
   WHILE @@FETCH_STATUS <> -1
   BEGIN   
          INSERT INTO #TMP_sortOutput (labelno,CntLocAisle,LocAisle,PicLoc) 
          VALUES (@c_Llabelno,@n_CntLocAisle,@c_GetLocAisle,@c_logicalLoc)

   FETCH NEXT FROM CUR_labelno INTO @c_Llabelno ,@c_GetLocAisle,@c_logicalLoc,@n_CntLocAisle                                   
   	
   END
   CLOSE CUR_labelno
   DEALLOCATE CUR_labelno   

 
 DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
 
   SELECT DISTINCT p.Storerkey,p.Pickslipno, p.CartonNo,t.labelno ,t.CntLocAisle,t.PicLoc,t.LocAisle
   FROM #tmp_sortOutput  t 
   JOIN #TMP_WAVEPICK P ON P.labelno=t.labelno
   ORDER BY t.CntLocAisle,t.LocAisle,t.PicLoc,t.labelno,p.Pickslipno

  OPEN CUR_StartRecLoop

  FETCH NEXT FROM CUR_StartRecLoop INTO  @c_storerkey
                                       , @c_Pickslipno
                                       , @c_cartonno
                                       , @c_labelno 
                                       , @n_CntLocAisle
                                       , @c_logicalLoc  
                                       , @c_GetLocAisle         
                                                          

   WHILE @@FETCH_STATUS <> -1
   BEGIN

   IF NOT EXISTS (SELECT 1 FROM #TMP_GETCOLUMN where col02 = @c_pickslipno and col03=@c_cartonno)        
   BEGIN
     INSERT INTO #TMP_GETCOLUMN (col01,col02,col03,col04,col05,col06,col07)
     VALUES(convert(nvarchar(20),@n_CntLocAisle),@c_logicalLoc,@c_GetLocAisle,@c_labelno,@c_Pickslipno,@c_cartonno,@c_storerkey)       
     
      IF ISNULL(@c_GetDatawindow,'') <> ''
         BEGIN      	   	        	
           EXEC isp_PrintToRDTSpooler 
                @c_ReportType  = @c_ReportID, 
                @c_Storerkey   = @c_Storerkey,
                @b_success		 = @b_success OUTPUT,
                @n_err			 = @n_err OUTPUT,
                @c_errmsg	    = @c_errmsg OUTPUT,
                @n_Noofparam   = @n_noofParm,
                @c_Param01     = @c_storerkey,
                @c_Param02     = @c_pickslipno,
                @c_Param03     = @c_cartonno,
                @c_Param04     = @c_cartonno,
                @c_Param05     = '',
                @c_Param06     = '',
                @c_Param07     = '',
                @c_Param08     = '',
                @c_Param09     = '',
                @c_Param10     = '',
                @n_Noofcopy    = 1,
                @c_UserName    = @c_UserId,
                @c_Facility    = '',
                @c_PrinterID   = @c_Getprinter,
                @c_Datawindow  = @c_GetDatawindow,
                @c_IsPaperPrinter = 'Y'
      
               IF @b_success <> 1 
               BEGIN
               	 --SELECT @n_continue = 3
                  GOTO QUIT_SP   
               END
         END 
     
    
     
   END

   FETCH NEXT FROM CUR_StartRecLoop INTO @c_storerkey
                                       , @c_Pickslipno
                                       , @c_cartonno
                                       , @c_labelno 
                                       , @n_CntLocAisle
                                       , @c_logicalLoc  
                                       , @c_GetLocAisle 

   END
   CLOSE CUR_StartRecLoop
   DEALLOCATE CUR_StartRecLoop

  SELECT col01 ,col02, col03, col04,col05,col06,col07
  FROM #TMP_GETCOLUMN

  
END


QUIT_SP:

GO