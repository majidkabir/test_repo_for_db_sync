SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/      
/* Stored Proc : isp_GetPickSlipWave_25                                    */      
/* Creation Date:14/07/2020                                                */      
/* Copyright: IDS                                                          */      
/* Written by:                                                             */      
/*                                                                         */      
/* Purpose: WMS-14144 -SG - THGBT - Wave Pick Slip Summary                 */      
/*                                                                         */      
/*                                                                         */      
/* Usage:                                                                  */      
/*                                                                         */      
/* Local Variables:                                                        */      
/*                                                                         */      
/* Called By: r_dw_print_wave_pickslip_25                                  */      
/*                                                                         */      
/* PVCS Version: 1.1                                                       */      
/*                                                                         */      
/* Version: 5.4                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date        Author      Ver   Purposes                                  */      
/* 27-JUL-2020 CSCHONG     1.1   WMS-14144 add generate pickslip (CS01)    */  
/***************************************************************************/      
  
CREATE PROC [dbo].[isp_GetPickSlipWave_25] (@c_wavekey NVARCHAR(10),   
                                            @c_Type NVARCHAR(10) = '')       
 AS      
 BEGIN      
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
DECLARE @n_continue         int,      
        @c_errmsg           NVARCHAR(255),      
        @b_success          int,      
        @n_err              int,      
        @c_sku              NVARCHAR(40),      
        @n_qty              int,      
        @c_loc              NVARCHAR(20),   
        @c_getloc           NVARCHAR(20),           
        @c_StorerKey        NVARCHAR(20),      
        @n_RowNo            int,      
        @c_AltSKU           NVARCHAR(40),      
        @c_areakey          NVARCHAR(10),      
        @c_skugroup         NVARCHAR(10),  
        @c_getwavekey       NVARCHAR(20),  
        @c_getcaseid        NVARCHAR(40),  
        @c_getLocPickZone   NVARCHAR(20),  
        @c_BFax2            NVARCHAR(20),  
        @c_BFax2a           NVARCHAR(20),  
        @n_Qty1             INT,  
        @c_BFax2b           NVARCHAR(20),  
        @n_Qty2             INT,  
        @c_BFax2c           NVARCHAR(20),  
        @n_Qty3             INT,  
        @c_BFax2d           NVARCHAR(20),  
        @n_Qty4             INT,   
        @c_BFax2e           NVARCHAR(20),  
        @n_Qty5             INT,  
        @n_currentpage      INT,  
        @n_ttlpage          INT,  
        @n_Maxline          INT,  
        @n_intFlag          INT,         
        @n_CntRec           INT,  
        @n_RecRowNo         INT,  
        @n_LineNum          INT,  
        @n_RecGrp           INT,  
        @n_TTLLinePerPage   INT,  
        @n_PageLine         INT,  
        @n_getttlpage       INT,  
        @n_getpageno        INT,  
        @n_maxdetailline    INT ,  
        @n_minrow           INT,  
        @n_Maxrow           INT,  
        @n_Rowid            INT,  
        @n_getrowid         INT,  
        @c_Presku           NVARCHAR(20),  
        @c_Preloc           NVARCHAR(10),  
        @c_prealtsku        NVARCHAR(20),  
        @n_prerowid         INT,  
        @n_DETLineID        INT,  
        @c_PrePickloc       NVARCHAR(10),  
        @c_precaseid        NVARCHAR(10),  
        @n_prepageno        INT,   
        @n_cntperpage       INT,  
        @n_cntlocperpage    INT,  
        @n_cntlocpzone      INT,  
        @n_Maxpageno        INT,  
        @n_Fttlpage         INT  
          
                        
    DECLARE @c_OrderKey          NVARCHAR(20),      
            @c_PrevPAZone        NVARCHAR(10),      
            @c_PZone             NVARCHAR(10),  
            @c_GetPickDetailKey  NVARCHAR(20),  
            @c_loadkey           NVARCHAR(20),  
            @c_RPickSlipNo       NVARCHAR(10),  
            @c_GetStorerkey      NVARCHAR(20),  
            @c_ExecStatement     NVARCHAR(4000) ,  
            @c_ExecArguments     NVARCHAR(4000),  
            @c_OrdLineNo         NVARCHAR(10),  
            @c_PickDetailKey     NVARCHAR(20)            
   
DECLARE @c_Prev_PK          NVARCHAR(20),  
        @c_Curr_PK          NVARCHAR(20),  
        @c_Prev_Zone        NVARCHAR(20),  
        @c_Curr_Zone        NVARCHAR(20),  
        @c_Prev_Loc         NVARCHAR(20),  
        @c_Curr_Loc         NVARCHAR(20),  
        @c_Prev_Logicallocation         NVARCHAR(20),  
        @c_Curr_Logicallocation         NVARCHAR(20),  
        @c_FirstRec         CHAR(1),  
        @c_Insert           CHAR(1),  
        @c_NewPK            CHAR(1),  
        @c_Add_PK_Page      CHAR(1),  
        @c_New_Loc          CHAR(1),  
        @c_Add_Loc_Row      CHAR(1),  
        @n_Tot_Cnt          Int,  
        @n_Rec_Cnt          Int,  
        @n_Loc_Row_Cnt      Int,  
        @n_PKPage           Int,  
        @n_PageRow          Int,  
        @n_Loc_Row          Int,  
        --@n_Rec_Row_Cnt      Int,  
        @n_PKPage_Row       Int,  
        @n_Row_Rec_Cnt      Int,  
        @c_Prev_Sku         NVARCHAR(20),  
        @c_Curr_Sku         NVARCHAR(20),  
        @c_Prev_AltSku      NVARCHAR(40),  
        @c_Curr_AltSku      NVARCHAR(40),  
        @n_PKZonePage       Int  
  
    SET @n_currentpage = 1  
    SET @n_ttlpage = 1  
    SET @n_Maxline = 5  
    SET @n_CntRec = 1      
    SET @n_intFlag = 1    
    SET @n_RecRowNo = 1  
    SET @n_TTLLinePerPage = 22  
    SET @n_maxdetailline = 8  
    SET @n_cntperpage = 0  
    SET @n_cntlocperpage = 0  
                
    Set @c_Prev_PK = ''  
    Set @c_Curr_PK = ''  
    Set @c_Prev_Zone = ''  
    Set @c_Curr_Zone = ''  
    Set @c_Prev_Loc = ''  
    Set @c_Curr_Loc = ''  
    Set @c_FirstRec = 'Y'  
    Set @c_Insert = 'N'  
    Set @c_NewPK = 'N'  
    Set @c_Add_PK_Page = 'N'  
    Set @c_New_Loc = 'N'  
    Set @c_Add_Loc_Row = 'N'  
    Set @n_Tot_Cnt = 0  
    Set @n_Rec_Cnt = 0  
    Set @n_Loc_Row_Cnt = 0  
    Set @n_PKPage = 1  
    --Set @n_PageRow = 1  
    Set @n_Loc_Row = 1  
    --Set @n_Rec_Row_Cnt = 0  
    Set @n_PKPage_Row = 1  
    Set @n_Row_Rec_Cnt = 0  
    Set @c_Prev_Sku = ''  
    Set @c_Curr_Sku = ''  
    Set @c_Prev_AltSku = ''  
    Set @c_Curr_AltSku = ''  
    Set @n_PKZonePage = 1  
  
    SET @c_BFax2a =''  
    SET @n_Qty1  = ''  
    SET @c_BFax2b = ''  
    SET @n_Qty2   = ''  
    SET @c_BFax2c = ''  
    SET @n_Qty3 = ''  
    SET @c_BFax2d = ''  
    SET @n_Qty4 = ''   
    SET @c_BFax2e = ''   
    SET @n_Qty5 = ''   
  
    CREATE TABLE #TEMP_WAVEPICK25     
    ( WaveKey       NVARCHAR(20) NULL,    
      caseid        NVARCHAR(40) NULL,      
      StorerKey     NVARCHAR(20),        
      LOC           NVARCHAR(30) NULL,      
      SKU           NVARCHAR(40),      
      LocPickZone   NVARCHAR(20) NULL,  
      Altsku        NVARCHAR(40) NULL,  
      RecRowNo      INT,   
      B_Fax2a       NVARCHAR(20) NULL,    
      Qty1          int NULL,  
      B_Fax2b       NVARCHAR(20) NULL,    
      Qty2          int NULL,     
      B_Fax2c       NVARCHAR(20) NULL,    
      Qty3          int NULL,  
      B_Fax2d       NVARCHAR(20) NULL,    
      Qty4          int NULL,  
      B_Fax2e       NVARCHAR(20) NULL,    
      Qty5          int NULL,  
      Pageno        INT NULL,  
      TTLPage       INT NULL,  
      Rowid         INT NULL,  
      LogicalLoc    NVARCHAR(36) NULL  
     )              
  
CREATE INDEX IDX_WAVEPICK25 ON #TEMP_WAVEPICK25(caseid)  
  
     CREATE TABLE #TEMP_WAVEPICK25_LOC(  
       [ID]          INT IDENTITY(1,1)  PRIMARY KEY  ,       
       WaveKey       NVARCHAR(20) NULL,    
       caseid        NVARCHAR(40) NULL,      
       StorerKey     NVARCHAR(20),   
       LocPickZone   NVARCHAR(20) NULL,      --CCH change to 20 from 10  
       Logicallocation   NVARCHAR(36) NULL,  --CCH added  
       SKU           NVARCHAR(40),      
       Altsku        NVARCHAR(20) NULL,  
       B_Fax2        NVARCHAR(20) NULL,   
       Qty           int,  
       LineNum       INT,  
       RecGrp        INT,  
       PageLine      INT,  
       BillContQty   INT,  
       Loc           NVARCHAR(20)   
                     
     )    
CREATE INDEX IDX_WAVEPICK25_LOC ON #TEMP_WAVEPICK25_LOC(caseid,Loc)  
  
  CREATE TABLE #TEMP_WAVETTLORD     
    (  WaveKey       NVARCHAR(20) NULL,    
       caseid        NVARCHAR(40) NULL,      
       StorerKey     NVARCHAR(20),   
     TTLORD        NVARCHAR(10) NULL,   
     SUSR5         NVARCHAR(36) NULL )  
  
  CREATE TABLE #TEMP_WAVETTLPICKFACE     
    (  Pickdetailkey     NVARCHAR(20) NULL,    
    PICKZONE          NVARCHAR(20) NULL,   
    LOGICALLOCATION   NVARCHAR(36) NULL,   
    LOC               NVARCHAR(20) NULL )  
  
CREATE INDEX IDX_WAVETTLPICKFACE ON #TEMP_WAVETTLPICKFACE(Pickdetailkey)  
  
     --CS01 START  
      SET @c_OrderKey = ''    
      --SET @c_Pickzone = ''  
      SET @c_PrevPAzone = ''  
      SET @c_getPickDetailKey = ''    
      SET @n_continue = 1  
      
   DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT oh.loadkey  
         , PID.orderkey   
         , L.PickZone  
        --, MAX(RowNo)   
        ,PickHeader.pickheaderkey  
        ,oh.storerkey  
   FROM wavedetail WD WITH (NOLOCK)  
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = WD.Orderkey  
   JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.Orderkey = OH.Orderkey  
   LEFT JOIN Pickheader WITH (NOLOCK) ON pickheader.orderkey = oh.orderkey and pickheader.loadkey = oh.loadkey  
   left outer join RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = pid.PickDetailKey)  
   JOIN SKU S WITH (NOLOCK) ON S.storerkey = PID.Storerkey AND S.sku = PID.sku  
   JOIN LOC L WITH (NOLOCK) ON L.loc = PID.loc  
   WHERE WD.Wavekey = @c_wavekey   
   AND  ISNULL(PickHeader.pickheaderkey,'') = ''  
   GROUP BY oh.loadkey  
         , PID.orderkey   
         , L.PickZone  
         , PickHeader.pickheaderkey  
         , oh.storerkey  
   ORDER BY oh.loadkey  
         , PID.orderkey   
         , L.PickZone  
        ,  PickHeader.pickheaderkey        
    
   OPEN CUR_LOAD    
       
   FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_orderkey     
                              ,  @c_PZone  
                                ,@c_GetPickDetailKey  
                                ,@c_GetStorerkey  
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN      
     --IF ISNULL(@c_OrderKey, '0') = '0'    
     --BREAK    
      
               
     --IF @c_PrevPAZone <> @c_PZone   
           
     -- BEGIN   
              
      SET @c_RPickSlipNo = ''  
        
      IF NOT EXISTS (SELECT 1 FROM  PICKHEADER (NOLOCK) WHERE wavekey = @c_Wavekey  AND Orderkey = @c_orderkey AND loadkey = @c_Loadkey)  
      BEGIN  
         EXECUTE nspg_GetKey         
                  'PICKSLIP'      
               ,  9      
               ,  @c_RPickSlipNo   OUTPUT      
               ,  @b_Success       OUTPUT      
               ,  @n_err           OUTPUT      
               ,  @c_errmsg        OUTPUT   
                          
         IF @b_success = 1     
         BEGIN                   
         SET @c_RPickSlipNo = 'P' + @c_RPickSlipNo            
                 
               INSERT INTO PICKHEADER        
                        (  PickHeaderKey      
                        ,  Wavekey      
                        ,  Orderkey      
                        ,  ExternOrderkey    
                        ,  Storerkey    
                        ,  Loadkey      
                        ,  PickType      
                        ,  Zone      
                        ,  consoorderkey  
                        ,  TrafficCop      
                        )        
               VALUES        
                        (  @c_RPickSlipNo      
                        ,  @c_Wavekey      
                        ,  @c_orderkey  
                        ,  @c_RPickSlipNo   
            ,  @c_GetStorerkey    
                        ,  @c_Loadkey      
                        ,  '1'       
                        ,  '3'    
                        ,  ''    
                        ,  ''      
                        )            
               
                     SET @n_err = @@ERROR        
                     IF @n_err <> 0        
                     BEGIN        
                        SET @n_continue = 3        
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)      
                        SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_GetPickSlipWave25)'     
                                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '     
                        GOTO QUIT_SP       
                     END             
          END  
          ELSE     
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @n_err = 63502  
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (isp_GetPickSlipWave25)'    
               BREAK     
            END          
     END   
  
         IF @n_Continue = 1    
         BEGIN          
            SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +  
                                    'SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber ' +     
                                    'FROM   PickDetail WITH (NOLOCK) ' +  
                                    'JOIN   OrderDetail WITH (NOLOCK) ' +                                         
                                    'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' +   
                                    'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +  
                                    'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +  
                                    'WHERE  PickDetail.pickdetailkey = @c_GetPickDetailKey ' +  
                                    ' AND    OrderDetail.LoadKey  =  @c_LoadKey ' +  
                                    ' AND Pickdetail.Orderkey = @c_orderkey ' +  
                                    ' AND LOC.Pickzone = RTRIM(@c_Pzone) ' +    
                                    ' ORDER BY PickDetail.PickDetailKey '    
     
            --EXEC(@c_ExecStatement)  
  
  
            SET @c_ExecArguments = N'     @c_GetPickDetailKey      NVARCHAR(20)'  
                                 +  ',    @c_LoadKey               NVARCHAR(20)'    
                                 +  ',    @c_Orderkey              NVARCHAR(20)'   
                                 +  ',    @c_Pzone                 NVARCHAR(20)'          
                             
                             
             EXEC sp_ExecuteSql    @c_ExecStatement         
                                 , @c_ExecArguments        
                                 , @c_GetPickDetailKey   
                                 , @c_LoadKey  
                                 , @c_orderkey  
                                 , @c_Pzone  
            OPEN C_PickDetailKey    
       
            FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo     
       
            WHILE @@FETCH_STATUS <> -1    
            BEGIN    
               IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_GetPickDetailKey)     
               BEGIN     
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)    
                  VALUES (@c_GetPickDetailKey, @c_RPickSlipNo, @c_OrderKey, @c_OrdLineNo, @c_Loadkey)  
  
                  SELECT @n_err = @@ERROR    
                  IF @n_err <> 0     
                  BEGIN    
                     SELECT @n_continue = 3  
                     SELECT @n_err = 63503  
                      SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_GetPickSlipWave25)'      
                      GOTO QUIT_SP  
                  END                            
               END     
       
               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo     
            END     
            CLOSE C_PickDetailKey     
            DEALLOCATE C_PickDetailKey          
         END     
                  
  
         SELECT @n_err = @@ERROR    
         IF @n_err <> 0     
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @n_err = 63504  
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #TMP_PICK Failed. (isp_GetPickSlipWave25)'      
            GOTO QUIT_SP  
         END  
  
                  UPDATE PICKDETAIL WITH (ROWLOCK)        
                   SET  PickSlipNo = @c_RPickSlipNo       
                   ,EditWho = SUSER_NAME()      
                   ,EditDate= GETDATE()       
                   ,TrafficCop = NULL       
               FROM ORDERS     OH WITH (NOLOCK)      
               JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey)   
               JOIN LOC L ON L.LOC = PD.Loc     
                --WHERE PD.OrderKey = @c_OrderKey    
                WHERE  L.Pickzone = @c_PZone  
                AND   ISNULL(PickSlipNo,'') = ''    
                AND Pickdetailkey = @c_GetPickDetailKey  
  
    
               SET @n_err = @@ERROR        
               IF @n_err <> 0        
               BEGIN        
                  SET @n_continue = 3        
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)      
                  SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_GetPickSlipWave25)'     
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '     
                  GOTO QUIT_SP       
               END    
           
               WHILE @@TRANCOUNT > 0    
               BEGIN    
                  COMMIT TRAN    
               END    
    
           
         WHILE @@TRANCOUNT > 0    
         BEGIN    
            COMMIT TRAN    
         END              
       
         SET @c_PrevPAzone = @c_Pzone                   
               
      FETCH NEXT FROM CUR_LOAD INTO @c_loadkey,@c_Orderkey    
                                 ,  @c_PZone  
                               --  ,  @n_MaxRow  
                                 , @c_GetPickDetailKey  
                                 , @c_getstorerkey  
   END    
   CLOSE CUR_LOAD    
   DEALLOCATE CUR_LOAD   
   --CS01 END        
  
   INSERT INTO #TEMP_WAVETTLORD(WaveKey,caseid,StorerKey,TTLORD,SUSR5)   
   SELECT WD.wavekey,PID.caseid,oh.storerkey,count(distinct oh.orderkey),MAX(ST.SUSR5)  
   from wavedetail WD WITH (NOLOCK)  
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = WD.Orderkey  
   JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.Orderkey = OH.Orderkey  
   JOIN STORER ST WITH (NOLOCK) ON ST.storerkey = OH.storerkey  
   WHERE wd.wavekey = @c_wavekey  
   group by WD.wavekey,PID.caseid,oh.storerkey   
  
   INSERT INTO #TEMP_WAVETTLPICKFACE  (Pickdetailkey, PICKZONE, LOGICALLOCATION,LOC)  
   SELECT PID.PickDetailKey,  
  PICKZONE =   
  CASE WHEN EXISTS (SELECT 1 FROM CODELKUP CLKA WHERE CLKA.LISTNAME = 'THGCUSREQ' AND CLKA.CODE = 'RETURNZONE'   
                          AND CLKA.STORERKEY = PID.Storerkey AND CLKA.CODE2 = L.PickZone)   
             THEN L.pickzone  
             ELSE  
                  CASE WHEN EXISTS (SELECT 1 FROM SKUxLOC SL WHERE SL.StorerKey = PID.STORERKEY AND SKU = PID.Sku AND LocationType IN ('PICK'))  
                       THEN (SELECT L1.Pickzone from Loc L1  
                             WHERE L1.LOC = (SELECT TOP 1 SL.LOC FROM SKUxLOC SL   
                                             WHERE SL.StorerKey = PID.STORERKEY AND SKU = PID.Sku AND LocationType IN ('PICK')   
                                             ORDER BY SL.LOC))  
                       ELSE  
                            L.pickzone  
                       END  
             END,   
  
  LOGICALLOCATION =   
        CASE WHEN EXISTS (SELECT 1 FROM CODELKUP CLKA WHERE CLKA.LISTNAME = 'THGCUSREQ' AND CLKA.CODE = 'RETURNZONE'   
                          AND CLKA.STORERKEY = PID.Storerkey AND CLKA.CODE2 = L.PickZone)   
             THEN L.Logicallocation  
             ELSE  
                  CASE WHEN EXISTS (SELECT 1 FROM SKUxLOC SL WHERE SL.StorerKey = PID.STORERKEY AND SKU = PID.Sku AND LocationType IN ('PICK'))  
                       THEN (SELECT L1.Logicallocation from Loc L1  
                             WHERE L1.LOC = (SELECT TOP 1 SL.LOC FROM SKUxLOC SL   
                                             WHERE SL.StorerKey = PID.STORERKEY AND SKU = PID.Sku AND LocationType IN ('PICK')   
                                             ORDER BY SL.LOC))  
                        ELSE  
                             L.Logicallocation  
                        END  
             END,   
  
  LOC =   
        CASE WHEN EXISTS (SELECT 1 FROM CODELKUP CLKA WHERE CLKA.LISTNAME = 'THGCUSREQ' AND CLKA.CODE = 'RETURNZONE'   
                          AND CLKA.STORERKEY = PID.Storerkey AND CLKA.CODE2 = L.PickZone)   
             THEN L.Loc  
             ELSE  
                  CASE WHEN EXISTS (SELECT 1 FROM SKUxLOC SL WHERE SL.StorerKey = PID.STORERKEY AND SKU = PID.Sku AND LocationType IN ('PICK'))  
                       THEN (SELECT TOP 1 SL.LOC FROM SKUxLOC SL   
                             WHERE SL.StorerKey = PID.STORERKEY AND SKU = PID.Sku AND LocationType IN ('PICK')   
                             ORDER BY SL.LOC)  
                       ELSE  
                            L.LOC  
                       END  
             END   
   FROM wavedetail WD, PICKDETAIL PID, LOC L  
   WHERE WD.OrderKey = PID.OrderKey  
   AND WD.WaveKey = @c_wavekey  
   AND PID.Loc = L.Loc  
  
  INSERT INTO #TEMP_WAVEPICK25_LOC (WaveKey,caseid, Storerkey,LocPickZone,Logicallocation,B_Fax2,Qty,sku,Altsku,--LineNum,RecGrp,PageLine,  
   BillContQty,Loc)  --CCH added Logicallocation  
   SELECT WD.wavekey,PID.caseid,OH.storerkey,TMP.PICKZONE,TMP.LOGICALLOCATION, oh.b_fax2,sum(PID.qty),s.sku,ISNULL(s.Altsku,'')   --CCH added Logicallocation  
        ,oh.BilledContainerQty, TMP.LOC  
   from wavedetail WD WITH (NOLOCK)  
   JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = WD.Orderkey  
   JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.Orderkey = OH.Orderkey  
   JOIN SKU S WITH (NOLOCK) ON S.storerkey = PID.Storerkey AND S.sku = PID.sku  
   JOIN #TEMP_WAVETTLPICKFACE TMP ON PID.PickDetailKey = TMP.Pickdetailkey  
   WHERE wd.wavekey = @c_wavekey  
   group by WD.wavekey,PID.caseid,oh.b_fax2,OH.storerkey,s.sku,ISNULL(s.Altsku,''), oh.BilledContainerQty, TMP.PICKZONE, TMP.LOGICALLOCATION, TMP.LOC --CCH added Logicallocation  
   --order by WD.wavekey desc,PID.caseid,L.pickzone,L.Logicallocation,s.sku,ISNULL(s.Altsku,''), oh.BilledContainerQty --CCH added Logicallocation  
   order by WD.wavekey desc,PID.caseid,TMP.PICKZONE, TMP.Logicallocation, oh.BilledContainerQty --CCH added Logicallocation  
  
   
   SET @c_PrePickloc=''  
   SET @c_precaseid = ''  
  
  
  SELECT @n_Tot_Cnt = COUNT(1)  
   FROM #TEMP_WAVEPICK25_LOC  
   DECLARE CUR_LineLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT ID,wavekey,caseid,LocPickZone,storerkey,sku,altsku,LineNum,RecGrp,PageLine, Logicallocation,Loc, B_Fax2,Qty  
   FROM   #TEMP_WAVEPICK25_LOC      
   WHERE wavekey = @c_wavekey   
   ORDER BY ID  
    
   OPEN CUR_LineLoop     
       
   FETCH NEXT FROM CUR_LineLoop INTO @n_DETLineID, @c_getwavekey,@c_Curr_PK, @c_Curr_Zone,@c_storerkey,@c_Curr_Sku,@c_Curr_AltSku,@n_lineNum,@n_RecGrp,@n_pageline, @c_Curr_Logicallocation, @c_Curr_Loc, @c_BFax2,@n_Qty  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN   
      IF @c_Prev_PK <> @c_Curr_PK  
      BEGIN  
         IF @c_FirstRec <> 'Y'  
         BEGIN  
            SET @c_Insert = 'Y'  
            SET @c_NewPK = 'Y'  
         END  
      END  
  
      IF (@c_Prev_PK = @c_Curr_PK) AND (@c_Prev_Zone <> @c_Curr_Zone)  
      BEGIN  
         SET @c_Insert = 'Y'  
         SET @c_Add_PK_Page = 'Y'  
      END  
  
      IF (@c_Prev_PK = @c_Curr_PK) AND (@c_Prev_Zone = @c_Curr_Zone)  
      BEGIN  
         IF @c_Prev_Loc <> @c_Curr_Loc  
         BEGIN  
            SELECT @n_Loc_Row_Cnt = CEILING(CAST(COUNT(1) AS DECIMAL(10,6))/CAST(@n_Maxline AS DECIMAL(10,6)))  
            FROM #TEMP_WAVEPICK25_LOC  
            WHERE caseid = @c_Curr_PK  
            AND Loc = @c_Curr_Loc  
     
            IF @n_Loc_Row_Cnt + @n_PKPage_Row > @n_maxdetailline  
            BEGIN  
               SET @c_Add_PK_Page = 'Y'  
            END  
            ELSE  
            BEGIN  
               SET @c_New_Loc = 'Y'  
            END  
          SET @c_Insert = 'Y'  
         END  
  
         ELSE  
         BEGIN  
            SET @n_Row_Rec_Cnt = @n_Row_Rec_Cnt + 1  
            IF @n_Row_Rec_Cnt > @n_Maxline  
            BEGIN  
               SET @c_Insert = 'Y'  
               SET @c_Add_Loc_Row = 'Y'  
            END  
         END  
      END  
  
      IF @c_Insert = 'Y'  
      BEGIN  
         INSERT INTO #TEMP_WAVEPICK25 (WaveKey,caseid, Storerkey,LogicalLoc ,LOC,SKU,    
                                        LocPickZone,Altsku,RecRowNo,Pageno,TTLPage,Rowid,   
                                        B_Fax2a, Qty1,B_Fax2b, Qty2,B_Fax2c, Qty3,B_Fax2d, Qty4,B_Fax2e, Qty5)          
         VALUES (@c_wavekey,@c_Prev_PK, @c_storerkey,@c_Prev_Logicallocation ,@c_Prev_Loc,@c_Prev_Sku,    
                                        @c_Prev_Zone,@c_Prev_AltSku,@n_Loc_Row,@n_PKPage,@n_PKPage,@n_PKZonePage,  
          @c_BFax2a,@n_Qty1,@c_BFax2b,@n_Qty2,@c_BFax2c,@n_Qty3,@c_BFax2d,@n_Qty4,@c_BFax2e,@n_Qty5)          
  
         SET @c_Insert = 'N'  
         SET @c_BFax2a =''  
         SET @n_Qty1  = ''  
         SET @c_BFax2b = ''  
         SET @n_Qty2   = ''  
         SET @c_BFax2c = ''  
         SET @n_Qty3 = ''  
         SET @c_BFax2d = ''  
         SET @n_Qty4 = ''   
         SET @c_BFax2e = ''   
         SET @n_Qty5 = ''   
         SET @n_Row_Rec_Cnt = 0  
  
         IF @c_NewPK = 'Y'  
         BEGIN  
            IF @n_PKPage > 1  
            BEGIN  
               UPDATE #TEMP_WAVEPICK25 SET TTLPage = @n_PKPage  
               WHERE caseid = @c_Prev_PK  
            END  
            SET @n_PKPage = 1  
            SET @n_PKPage_Row = 1  
            SET @c_NewPK = 'N'  
            SET @n_PKZonePage = 1  
            SET @n_Loc_Row = 1  
         END  
  
         IF @c_Add_PK_Page = 'Y'  
         BEGIN  
            SET @n_PKPage = @n_PKPage + 1  
            SET @n_PKPage_Row = 1  
            SET @n_Loc_Row = 1  
            SET @c_Add_PK_Page = 'N'  
            SET @n_PKZonePage = @n_PKZonePage + 1  
            IF @c_Prev_Zone <> @c_Curr_Zone  
            BEGIN  
               SET @n_PKZonePage = 1  
            END  
         END  
  
         IF @c_New_Loc = 'Y'  
         BEGIN  
            SET @n_PKPage_Row = @n_PKPage_Row + 1  
            SET @n_Loc_Row = 1  
            SET @c_New_Loc = 'N'  
         END  
  
         IF @c_Add_Loc_Row = 'Y'  
         BEGIN  
            SET @n_PKPage_Row = @n_PKPage_Row + 1  
            SET @n_Loc_Row = @n_Loc_Row + 1  
            SET @c_Add_Loc_Row = 'N'  
         END  
      END  
  
      IF @n_Row_Rec_Cnt = 0  
      BEGIN  
           SET @n_Row_Rec_Cnt = 1  
      END  
  
      IF @n_Row_Rec_Cnt = 1  
      BEGIN  
         SET @c_BFax2a = @c_BFax2  
         SET @n_Qty1  = @n_Qty  
      END  
      IF @n_Row_Rec_Cnt = 2  
      BEGIN  
         SET @c_BFax2b  = @c_BFax2  
         SET @n_Qty2  = @n_Qty  
      END  
      IF @n_Row_Rec_Cnt = 3  
      BEGIN  
         SET @c_BFax2c = @c_BFax2  
         SET @n_Qty3  = @n_Qty  
      END  
      IF @n_Row_Rec_Cnt = 4  
      BEGIN  
         SET @c_BFax2d = @c_BFax2  
         SET @n_Qty4  = @n_Qty  
      END  
      IF @n_Row_Rec_Cnt = 5  
      BEGIN  
         SET @c_BFax2e = @c_BFax2  
         SET @n_Qty5  = @n_Qty  
      END  
  
      SET @c_Prev_PK = @c_Curr_PK  
      SET @c_Prev_Zone = @c_Curr_Zone  
      SET @c_Prev_Logicallocation = @c_Curr_Logicallocation  
      SET @c_Prev_Loc = @c_Curr_Loc  
      SET @c_Prev_Sku = @c_Curr_Sku  
      SET @c_Prev_AltSku = @c_Curr_AltSku  
      SET @c_FirstRec = 'N'  
      SET @n_Rec_Cnt = @n_Rec_Cnt + 1  
  
      IF @n_Rec_Cnt = @n_Tot_Cnt  
      BEGIN  
         INSERT INTO #TEMP_WAVEPICK25 (WaveKey,caseid, Storerkey, LogicalLoc, LOC,SKU,    
                                        LocPickZone,Altsku,RecRowNo,Pageno,TTLPage,Rowid,   
                                        B_Fax2a, Qty1,B_Fax2b, Qty2,B_Fax2c, Qty3,B_Fax2d, Qty4,B_Fax2e, Qty5)          
         VALUES (@c_wavekey,@c_Prev_PK, @c_storerkey,@c_Prev_Logicallocation,@c_Prev_Loc,@c_Prev_Sku,    
                                        @c_Prev_Zone,@c_Prev_AltSku,@n_Loc_Row,@n_PKPage,@n_PKPage,@n_PKZonePage,  
          @c_BFax2a,@n_Qty1,@c_BFax2b,@n_Qty2,@c_BFax2c,@n_Qty3,@c_BFax2d,@n_Qty4,@c_BFax2e,@n_Qty5)  
  
         IF @n_PKPage > 1  
         BEGIN  
            UPDATE #TEMP_WAVEPICK25 SET TTLPage = @n_PKPage  
            WHERE caseid = @c_Prev_PK  
         END  
      END  
  
--   FETCH NEXT FROM CUR_LineLoop INTO @n_DETLineID,@c_getwavekey,@c_getcaseid, @c_getlocpickzone,@c_storerkey,@c_sku,@c_altsku,@n_lineNum,@n_RecGrp,@n_pageline  
   FETCH NEXT FROM CUR_LineLoop INTO @n_DETLineID, @c_getwavekey,@c_Curr_PK, @c_Curr_Zone,@c_storerkey,@c_Curr_Sku,@c_Curr_AltSku,@n_lineNum,@n_RecGrp,@n_pageline, @c_Curr_Logicallocation, @c_Curr_Loc, @c_BFax2,@n_Qty  
   END    
   CLOSE CUR_LineLoop    
   DEALLOCATE CUR_LineLoop       
  
      SELECT  TORD.TTLORD,TORD.SUSR5, TWP25.Storerkey, TWP25.LOC,TWP25.SKU,    
             TWP25.RecRowNo,TWP25.LocPickZone,TWP25.Pageno,TWP25.TTLPage,TWP25.Altsku,  
             B_Fax2a,B_Fax2b,TWP25.caseid,TWP25.WaveKey,B_Fax2c,B_Fax2d,B_Fax2e,Qty1,  
             Qty2,Qty3,Qty4,Qty5   
             ,TWP25.rowid--,TWP25.logicalloc  
            --,ROW_NUMBER() OVER ( PARTITION BY TWP25.wavekey,TWP25.caseid,TWP25.locpickzone   
            --             ORDER BY TWP25.wavekey,TWP25.caseid,TWP25.locpickzone  )/@n_maxdetailline + 1  as rowid     
      FROM #TEMP_WAVEPICK25 TWP25  
      JOIN #TEMP_WAVETTLORD TORD ON TORD.WaveKey = TWP25.WaveKey AND TORD.caseid=TWP25.caseid   
      AND TORD.StorerKey= TWP25.StorerKey    
      ORDER BY Wavekey,Caseid,LocPickZone,TWP25.logicalloc,loc,sku,altsku,recrowno,pageno   
         
   DROP Table #TEMP_WAVEPICK25    
   DROP Table #TEMP_WAVEPICK25_LOC  
   DROP Table #TEMP_WAVETTLORD   
   DROP Table #TEMP_WAVETTLPICKFACE  
QUIT_SP:    
END    

GO