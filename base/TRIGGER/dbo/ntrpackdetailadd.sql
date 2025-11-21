SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/        
/* Trigger: ntrPackDetailAdd                                             */        
/* Creation Date:                                                        */        
/* Copyright: IDS                                                        */        
/* Written by:                                                           */        
/*                                                                       */        
/* Purpose:                                                              */        
/*                                                                       */        
/* Input Parameters: NONE                                                */        
/*                                                                       */        
/* Output Parameters: NONE                                               */        
/*                                                                       */        
/* Return Status: NONE                                                   */        
/*                                                                       */        
/* Usage:                                                                */        
/*                                                                       */        
/* Local Variables:                                                      */        
/*                                                                       */        
/* Called By: When records added                                         */        
/*                                                                       */        
/* PVCS Version: 3.2                                                     */        
/*                                                                       */        
/* Version: 5.4                                                          */        
/*                                                                       */        
/* Data Modifications:                                                   */        
/*                                                                       */        
/* Updates:                                                              */        
/* Date        Author   Ver.  Purposes                                   */        
/* 2009-Mar-03 James    1.1   Filter by checking labelno = '' to cater   */        
/*                            for DynamicPick parallel picking           */        
/*                            (james01)                                  */        
/* 2009-Jul-02 Shong    1.2   Bug fix for DynamicPick LabelNo(Shong01)   */        
/* 2009-Jul-08 Vicky    1.3   Assign CartonNo to prevent different       */        
/*                            LabelNo being assigned same CartonNo       */        
/*                            (Vicky01)                                  */        
/* 2010-Nov-10 NJOW01   1.4   Fix the MAX(cartonno)                      */        
/* 2011-Jan-12 NJOW02   1.5   201874-Insert copy dropid value from       */        
/*                            previous line                              */        
/* 2013-Jul-17 SHONG    1.6   Update PackDetail with ArchiveCop When     */      
/*                            assign new carton number                   */      
/* 2014-Jan-08 Ung      1.7   Auto assign cartonno when labelno blank    */      
/*                            Fix duplicate cartonno even diff labelno   */      
/*                            Add RDT compatible message                 */      
/* 2014-Apr-14 TLTING   1.8   SQL2012                                    */      
/* 2014-May-06 TLTING   1.8   Deadlock Fix                               */      
/* 2015-Aug-24 NJOW03   1.9   346367-copy lableno to dropid if blank     */       
/* 2015-Nov-30 NJOW04   2.0   356837-fix insert packdetail update to     */      
/*                            packinfo.qty                               */      
/* 2019-Apr-23 TLTING01 2.1 Deadlock tune                              */       
/* 2019-Jul-19 WLChooi  2.2   WMS-9661 & WMS-9663 - Add CartonGID when   */       
/*                            add new carton - Based on storerconfig     */      
/*                            Use nspGetRight to get Storerconfig to     */      
/*                            filter by Facility for Pickslipno start    */      
/*                            with P only (Non-ECOM)                     */      
/*                            For ECOM, will be done in update trigger   */      
/*                            (WL01)                                     */      
/* 2020-Apr-15 WLChooi  2.3   WMS-9661 Fix - Update CartonType (WL02)    */      
/* 2020-May-15 WLChooi  2.4   Insert PACKInfo table with CartonType =    */      
/*                             NULL (WL03)                               */      
/* 2020-Sep-01 NJOW05   2.5   WMS-15009 - call custom stored proc        */      
/* 2021-Jul-30 NJOW06   2.6   WMS-17609 - call custom stored proc to     */      
/*                            generate packinfo trackingno               */     
/* 2021-Nov-26 Wan01    2.7   WMS-18410 - [RG] Logitech Tote ID Packing  */    
/*                            Change Request                             */    
/* 2021-Nov-26 Wan01    2.8   DevOps Conbine Script                      */    
/* 2021-DEC-15 Wan02    2.9   Add RowLock & fixed Order By               */    
/* 2021-DEC-29 Wan05    3.1   JSM-41421 Gen 1 PackDetailLabel Rec with   */
/*                                          same Carton                  */ 
/* 2022-FEB-09 Wan04    3.2   Enhancement if reduce 1 carton Multi label#*/
/*************************************************************************/        
        
CREATE TRIGGER [dbo].[ntrPackDetailAdd]        
ON  [dbo].[PackDetail]        
FOR INSERT        
AS        
BEGIN        
  SET NOCOUNT ON        
  SET ANSI_NULLS OFF        
  SET QUOTED_IDENTIFIER OFF        
  SET CONCAT_NULL_YIELDS_NULL OFF        
        
DECLARE        
          @b_Success    INT       -- Populated by calls to stored procedures - was the proc successful?        
,         @n_err        INT       -- Error number returned by stored procedure or this trigger        
,         @n_err2       INT       -- For Additional Error Detection        
,         @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger        
,         @n_continue   INT                         
,         @n_starttcnt  INT       -- Holds the current transaction count        
,         @c_preprocess NVARCHAR(250) -- preprocess        
,         @c_pstprocess NVARCHAR(250) -- post process        
,         @n_cnt        INT                          
        
DECLARE @nMax_CartonNo              INT -- (Vicky01)        
       ,@nCartonNo                  INT        
       ,@cLabelLine                 NVARCHAR(5)        
       ,@cDropID                    NVARCHAR(20) --NJOW02       
       ,@c_Storerkey                NVARCHAR(10) --WL01      
       ,@c_Facility                 NVARCHAR(10) --WL01       
       ,@c_CartonGID                NVARCHAR(50) --WL01      
       ,@c_DefaultPackInfo          NVARCHAR(10) = ''  --WL01      
       ,@c_CapturePackInfo          NVARCHAR(10) = ''  --WL01      
       ,@c_PackCartonGID            NVARCHAR(10) = ''  --WL01      
       ,@c_Pickslipno               NVARCHAR(10) --NJOW06      
       ,@n_CartonNo                 INT --NJOW06      
       ,@c_PackinfoGenTrackingNo_SP NVARCHAR(30) --NJOW06     
                                                     
      , @c_AdvancePackGenCartonNo   NVARCHAR(10) = ''    --(Wan01)    

      , @n_RowID_LastCarton         BIGINT       = 0     --(Wan04)
                
   DECLARE @t_PackdetailLabel TABLE (RowId BIGINT NOT NULL, PickSlipNo  NVARCHAR(10) NOT NULL DEFAULT (''))       --(Wan01) 
   
   DECLARE @t_CartonUpd TABLE       (CartonNo INT NOT NULL DEFAULT (0))                                             --(Wan04)       
   DECLARE @n_MaxCartonNo_Upd       INT    = 0                                                                           --(Wan04)
         , @n_RowID_UPD             BIGINT = 0
         , @n_CartonNo_PDL          INT    = 0                                                                 
         , @n_CartonNo_Upd          INT    = 0
         , @c_PickSlipNo_Upd        NVARCHAR(10) = ''
         , @c_LabelNo_Upd           NVARCHAR(20) = '' 
         , @n_Try                   INT    = 0   
         , @c_ms                    CHAR(5) =  ''
         , @c_delay                 NVARCHAR(12) = '00:00:0'  
         , @CUR_UPD                 CURSOR          
                                                                                                                  
        
SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT        
      /* #INCLUDE <TRCCA1.SQL> */             
      
IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')        
BEGIN        
   SELECT @n_continue = 4        
END        
   --Get Facility and Configkey (WL01 Start)      
   IF @n_continue = 1 or @n_continue = 2        
   BEGIN       
      SELECT TOP 1 @c_Storerkey = PACKHEADER.StorerKey      
      FROM INSERTED      
      JOIN PACKHEADER (NOLOCK) ON INSERTED.PickSlipNo = PACKHEADER.PickSlipNo       
      
      SELECT TOP 1 @c_Facility = Facility      
      FROM INSERTED      
      JOIN PACKHEADER (NOLOCK) ON INSERTED.PickSlipNo = PACKHEADER.PickSlipNo       
      JOIN ORDERS (NOLOCK) ON PACKHEADER.StorerKey = ORDERS.StorerKey AND PACKHEADER.OrderKey = ORDERS.OrderKey      
            
      IF(ISNULL(@c_Facility,'') = '')      
      BEGIN      
         SELECT TOP 1 @c_Facility = ORDERS.Facility      
         FROM INSERTED      
         JOIN PACKHEADER (NOLOCK) ON INSERTED.PickSlipNo = PACKHEADER.PickSlipNo       
         JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.LOADKEY = PACKHEADER.LOADKEY      
         JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY      
      END      
      
      EXEC nspGetRight         
         @c_Facility          -- facility        
      ,  @c_Storerkey         -- Storerkey        
      ,  NULL                 -- Sku        
      ,  'Default_PackInfo'   -- Configkey        
      ,  @b_Success           OUTPUT         
      ,  @c_DefaultPackInfo   OUTPUT         
      ,  @n_Err               OUTPUT         
      ,  @c_ErrMsg            OUTPUT       
      
      IF @b_success <> 1        
      BEGIN        
         SET @n_continue = 3        
         SET @n_err = 83049         
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ntrPackdetailAdd)'         
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '          
      END      
            
      EXEC nspGetRight         
         @c_Facility          -- facility        
      ,  @c_Storerkey         -- Storerkey        
      ,  NULL                 -- Sku        
      ,  'PackCartonGID'      -- Configkey        
      ,  @b_Success           OUTPUT         
      ,  @c_PackCartonGID     OUTPUT         
      ,  @n_Err               OUTPUT         
      ,  @c_ErrMsg            OUTPUT       
            
      IF @b_success <> 1        
      BEGIN        
         SET @n_continue = 3        
         SET @n_err = 83050         
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ntrPackdetailAdd)'         
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '         
      END       
   END      
   --(WL01 End)      
         
   --NJOW05      
   IF @n_continue=1 or @n_continue = 2      
   BEGIN      
      IF EXISTS (SELECT 1 FROM INSERTED i      
                 JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey      
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue      
                 WHERE  s.configkey = 'PackdetailTrigger_SP')      
      BEGIN      
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL      
            DROP TABLE #INSERTED      
      
          SELECT *      
          INTO #INSERTED      
          FROM INSERTED      
      
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL      
            DROP TABLE #DELETED      
      
          SELECT *      
          INTO #DELETED      
          FROM DELETED      
      
         EXECUTE dbo.isp_PackdetailTrigger_Wrapper      
                   'INSERT'  --@c_Action      
                 , @b_Success  OUTPUT      
                 , @n_Err      OUTPUT      
                 , @c_ErrMsg   OUTPUT      
      
         IF @b_success <> 1      
         BEGIN      
            SELECT @n_continue = 3      
                  ,@c_errmsg = 'ntrPackDetailAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))      
         END      
      
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL      
            DROP TABLE #INSERTED      
      
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL      
            DROP TABLE #DELETED      
      END      
   END      
        
   IF @n_continue = 1 or @n_continue = 2        
   BEGIN        
      /*        
          IF Exists (SELECT 1         
                     FROM PackDetail With (NOLOCK), INSERTED        
                     WHERE PackDetail.PickSlipNo = INSERTED.PickSlipNo        
                     AND PackDetail.LabelNo = INSERTED.LabelNo        
                     AND PackDetail.CartonNo <> INSERTED.CartonNo         
                     AND INSERTED.LabelNo <> '')   -- (james01)        
      */        
              
      --NJOW02        
      IF Exists (SELECT 1 FROM INSERTED WITH (NOLOCK) WHERE ISNULL(INSERTED.dropid,'') = '')        
      BEGIN        
         SELECT @cDropID = MAX(PACKDETAIL.DropID)  --NJOW01        
              FROM PACKDETAIL WITH (NOLOCK)        
              JOIN INSERTED WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo          
                                              AND   PACKDETAIL.CartonNo = INSERTED.CartonNo    -- tlting01      
                                              AND PACKDETAIL.LabelNo = INSERTED.LabelNo)        
         IF ISNULL(@cDropID,'') <> ''        
         BEGIN        
             UPDATE PACKDETAIL        
             SET DropID = @cDropID        
             FROM INSERTED WITH (NOLOCK)        
             WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
             AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
             AND   PACKDETAIL.CartonNo = INSERTED.CartonNo    -- tlting01      
             AND   ISNULL(PACKDETAIL.DropID,'') = ''        
         END                                                          
      END        
            
      --NJOW03      
      IF EXISTS (SELECT 1       
                 FROM INSERTED       
                 JOIN STORERCONFIG SC (NOLOCK) ON INSERTED.Storerkey = SC.Storerkey AND SC.Configkey = 'PackCopyLabelNoToDropId' AND SC.Svalue = '1'      
                 AND ISNULL(INSERTED.DropID,'')='')        
      BEGIN      
          UPDATE PACKDETAIL        
          SET PACKDETAIL.DropID = PACKDETAIL.Labelno      
          FROM INSERTED WITH (NOLOCK)        
          JOIN STORERCONFIG SC (NOLOCK) ON INSERTED.Storerkey = SC.Storerkey AND SC.Configkey = 'PackCopyLabelNoToDropId' AND SC.Svalue = '1'                    
          WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
          AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
          AND   PACKDETAIL.CartonNo = INSERTED.CartonNo    -- tlting01      
          AND   ISNULL(PACKDETAIL.DropID,'') = ''        
      END     
          
      --(Wan01) - START    
      SELECT @c_AdvancePackGenCartonNo = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AdvancePackGenCartonNo')      
      IF @c_AdvancePackGenCartonNo = '1'    
      BEGIN    
         --INSERT INTO PACKDETAILLABEL (PickSlipNo, LabelNo, CartonNo) OUTPUT INSERTED.RowID, INSERTED.PickSlipNo INTO @t_PackdetailLabel    
         --SELECT i.PickSlipNo, i.LabelNo, i.CartonNo    
         --FROM INSERTED i    
         --GROUP BY i.PickSlipNo, i.LabelNo, i.CartonNo    

         INSERT INTO PACKDETAILLABEL (PickSlipNo, LabelNo, CartonNo) OUTPUT INSERTED.RowID, INSERTED.PickSlipNo INTO @t_PackdetailLabel   --(Wan05)
         SELECT i.PickSlipNo, i.LabelNo, i.CartonNo
         FROM INSERTED i
         LEFT JOIN dbo.PackdetailLabel AS pl (NOLOCK) ON i.PickSlipNo = pl.PickSlipNo AND i.LabelNo = pl.LabelNo AND i.CartonNo = pl.CartonNo
         WHERE pl.RowID IS NULL
         GROUP BY i.PickSlipNo, i.LabelNo, i.CartonNo
      END    
      --(Wan01) - END               
            
      IF Exists (SELECT 1 FROM INSERTED WITH (NOLOCK) WHERE INSERTED.CartonNo = 0 AND LabelNo = '')      
      BEGIN        
              SELECT @nMax_CartonNo = MAX(PACKDETAIL.CartonNo)      
              FROM PACKDETAIL WITH (NOLOCK)        
              JOIN INSERTED WITH (NOLOCK) ON PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
      
              UPDATE PACKDETAIL        
               SET CartonNo = @nMax_CartonNo + 1,        
                   LabelLine = CASE WHEN INSERTED.LabelLine = '' THEN '00001' ELSE INSERTED.LabelLine END,       
                   ArchiveCop = NULL      
              FROM INSERTED WITH (NOLOCK)        
              WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
              AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
              AND   PACKDETAIL.CartonNo = 0       
              AND   PACKDETAIL.LabelNo = ''      
      
              IF EXISTS ( SELECT 1       
                 FROM PACKDETAIL (NOLOCK)       
                 JOIN INSERTED WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo AND         
                                                 PACKDETAIL.LabelNo = INSERTED.LabelNo)        
                 WHERE PACKDETAIL.CartonNo = @nMax_CartonNo + 1       
                 HAVING COUNT( 1) > 1)       
              BEGIN      
                 SELECT @n_err = 83051        
                 SELECT @n_continue = 3        
                 SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+ ': CartonNo repeated (ntrPackdetailAdd)'      
              END      
      END      
      ELSE      
      -- (Vicky01) - Start        
      IF Exists (SELECT 1 FROM INSERTED WITH (NOLOCK) WHERE INSERTED.CartonNo = 0)        
      BEGIN        
         SELECT @nCartonNo = MAX(PACKDETAIL.CartonNo)  --NJOW01        
         FROM PACKDETAIL WITH (NOLOCK)        
         JOIN INSERTED WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo AND         
                                          PACKDETAIL.LabelNo = INSERTED.LabelNo)        
        
         IF @nCartonNo = 0        
         BEGIN        
            SELECT @nMax_CartonNo = MAX(PACKDETAIL.CartonNo)      
            FROM PACKDETAIL WITH (NOLOCK)        
            JOIN INSERTED WITH (NOLOCK) ON PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo      
        
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( INSERTED.LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)        
            FROM PACKDETAIL WITH (NOLOCK)        
            JOIN INSERTED WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo AND         
                                             PACKDETAIL.LabelNo = INSERTED.LabelNo)        
    
            --(Wan01) - START    
            IF @c_AdvancePackGenCartonNo = '1'    
            BEGIN    
               SELECT TOP 1 @nMax_CartonNo = pdl.CartonNo   
                            , @n_RowID_LastCarton = pdl.RowId             --(Wan04) 
               FROM PACKDETAILLABEL pdl WITH (NOLOCK)    
               JOIN @t_PackdetailLabel AS tpl ON tpl.PickSlipNo = pdl.PickSlipNo    
               WHERE pdl.RowId < tpl.RowId    
               AND CartonNo > 0    
               ORDER BY pdl.CartonNo DESC          --Wan02    
               --ORDER BY pdl.RowID DESC              --Wan02    
                 
               --(Wan04) - START    
               --;WITH GC AS     
               --( SELECT pdl.RowID     
               --      ,  pdl.PickSlipNo    
               --      ,  pdl.LabelNo    
               -- ,  CartonNo = @nMax_CartonNo + ROW_NUMBER() OVER (ORDER BY pdl.RowId)    
               --  FROM PACKDETAILLABEL pdl WITH (NOLOCK)    
               --  JOIN @t_PackdetailLabel AS tpl ON tpl.PickSlipNo = pdl.PickSlipNo    
               --  WHERE pdl.CartonNo = 0    
               --)    
                   
               --UPDATE pdl WITH (ROWLOCK)           --Wan02    
               --   SET CartonNo  = GC.CartonNo     
               --   ,   EditWho = SUSER_SNAME()         --Wan02      
               --   ,   EditDate = GETDATE()            --Wan02        
               --FROM GC    
               --JOIN PACKDETAILLABEL pdl ON GC.RowID = pdl.RowID    
               --JOIN INSERTED ON  INSERTED.PickSlipNo = pdl.PickSlipNo    
               --              AND INSERTED.LabelNo = pdl.LabelNo        
               --WHERE pdl.CartonNo = 0 
                   
               SET @n_Try = 0          
               RETRY:
               
               SET @CUR_UPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT pdl.RowID 
                     ,CartonNo = @nMax_CartonNo + ROW_NUMBER() OVER (ORDER BY pdl.PickSlipNo, pdl.RowId)
                     ,pdl.PickSlipNo
                     ,pdl.LabelNo
                     ,pdl.CartonNo 
               FROM PACKDETAILLABEL pdl WITH (NOLOCK)
               JOIN @t_PackdetailLabel AS tpl ON tpl.PickSlipNo = pdl.PickSlipNo
               WHERE pdl.RowID > @n_RowID_LastCarton
                 
               OPEN @CUR_UPD
   
               FETCH NEXT FROM @CUR_UPD INTO @n_RowID_UPD, @n_CartonNo_Upd, @c_PickSlipNo_Upd, @c_LabelNo_Upd, @n_CartonNo_PDL
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @n_CartonNo_PDL = 0 AND EXISTS ( SELECT 1 FROM  INSERTED
                                                      WHERE Inserted.PickSlipNo = @c_PickSlipNo_Upd
                                                      AND   Inserted.LabelNo = @c_LabelNo_Upd
                                                    )
                  BEGIN
                     IF EXISTS (SELECT 1 FROM PACKDETAILLABEL pdl WITH (NOLOCK) WHERE pdl.PickSlipNo = @c_PickSlipNo_Upd AND pdl.CartonNo = @n_CartonNo_Upd)
                     BEGIN
                        SET @n_Try = @n_Try + 1
                        BREAK
                     END
                     
                     SET @n_MaxCartonNo_Upd = @n_CartonNo_Upd - 1             -- Need to Set correct @nMax_CartonNo as check repeated CartonNo by  @nMax_CartonNo + 1
                     UPDATE pdl WITH (ROWLOCK)           
                              SET CartonNo  = @n_CartonNo_Upd  
                              ,   EditWho = SUSER_SNAME()          
                              ,   EditDate = GETDATE()  
                     FROM PACKDETAILLABEL pdl 
                     JOIN INSERTED ON  INSERTED.PickSlipNo = pdl.PickSlipNo  
                                   AND INSERTED.LabelNo = pdl.LabelNo      
                     WHERE pdl.CartonNo = 0   
                     AND   pdl.RowID = @n_RowID_UPD 
                     
                     SET @n_Try = 0  
                  END
                  FETCH NEXT FROM @CUR_UPD INTO @n_RowID_UPD, @n_CartonNo_Upd, @c_PickSlipNo_Upd, @c_LabelNo_Upd, @n_CartonNo_PDL
               END
               CLOSE @CUR_UPD
               DEALLOCATE @CUR_UPD  
               
               IF @n_Try > 0 AND @n_Try <= 5
               BEGIN
                  SET @c_ms =CONVERT(CHAR(5) , CONVERT(DECIMAL(5,3), RAND()))
                  SET @c_delay = @c_delay + @c_ms
                  WAITFOR DELAY @c_delay
                  GOTO RETRY
               END
               
               IF @n_MaxCartonNo_Upd <> @nMax_CartonNo                   -- Need to Set correct @nMax_CartonNo as check repeated CartonNo by  @nMax_CartonNo + 1
               BEGIN
                  SET @nMax_CartonNo = @n_MaxCartonNo_Upd              
               END               
               --(Wan04) - END
                   
               UPDATE PACKDETAIL        
                  SET CartonNo  = pdl.CartonNo      
                     ,LabelLine = @cLabelLine      
                     ,ArchiveCop = NULL     
               FROM PACKDETAILLABEL pdl WITH (NOLOCK)      
               JOIN INSERTED ON  INSERTED.PickSlipNo = pdl.PickSlipNo    
                             AND INSERTED.LabelNo = pdl.LabelNo        
               WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
               AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
               AND   PACKDETAIL.CartonNo = 0      
            END     
            ELSE     
            BEGIN    
               --Original Update for AdvancePackGenCartonNo turn off    
               UPDATE PACKDETAIL        
                  SET CartonNo = @nMax_CartonNo + 1,        
                        LabelLine = @cLabelLine      
                        ,ArchiveCop = NULL  -- 2013-Jul-17  SHONG      
               FROM INSERTED WITH (NOLOCK)        
               WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
               AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
               AND   PACKDETAIL.CartonNo = 0        
            END    
            --(Wan01) - END    
                
            IF EXISTS ( SELECT 1       
               FROM PACKDETAIL (NOLOCK)       
               JOIN INSERTED WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo)        
               WHERE PACKDETAIL.CartonNo = @nMax_CartonNo + 1       
               HAVING COUNT( DISTINCT PACKDETAIL.LabelNo) > 1)       
            BEGIN      
               SELECT @n_err = 83052        
               SELECT @n_continue = 3        
               SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+ ': CartonNo repeated (ntrPackdetailAdd)'      
            END      
         END        
         ELSE        
         BEGIN        
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( PACKDETAIL.LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)        
            FROM PACKDETAIL WITH (NOLOCK)        
            JOIN INSERTED WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo AND         
                                             PACKDETAIL.LabelNo = INSERTED.LabelNo)        
            WHERE PACKDETAIL.CartonNo = @nCartonNo        
                          
            UPDATE PACKDETAIL        
               SET CartonNo = @nCartonNo,        
                     LabelLine = @cLabelLine,       
                     ArchiveCop = NULL -- 2013-Jul-17  SHONG      
            FROM INSERTED WITH (NOLOCK)        
            WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
            AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
            AND   PACKDETAIL.CartonNo = 0        
         END        
      END        
      -- (Vicky01) - End        
      ELSE IF Exists (SELECT 1         
                  FROM INSERTED With (NOLOCK)         
                      LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo        
                      WHERE ( ( PackDetail.LabelNo = INSERTED.LabelNo AND PackDetail.CartonNo <> INSERTED.CartonNo) OR         
                              ( PackDetail.LabelNo <> INSERTED.LabelNo AND PackDetail.CartonNo = INSERTED.CartonNo) )         
                             AND INSERTED.LabelNo <> '')   -- (Shong01)        
      BEGIN        
         SELECT @n_continue = 3        
         SELECT @n_err=83053        
      -- SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Same LabelNo Not Allow to have Different CartonNo for Same PickSlip No. (ntrPackDetailAdd)'        
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': LabelNo and CartonNo are not unique for each other. (ntrPackDetailAdd)' -- (Shong01)        
      END          
   END        
         
   --NJOW06      
   IF @n_continue = 1 or @n_continue = 2           
   BEGIN                                                   
      EXEC nspGetRight        
           @c_Facility  = @c_Facility,        
           @c_StorerKey = @c_StorerKey,        
           @c_sku       = NULL,        
           @c_ConfigKey = 'PackinfoGenTrackingNo_SP',         
           @b_Success   = @b_Success                  OUTPUT,        
           @c_authority = @c_PackinfoGenTrackingNo_SP OUTPUT,         
           @n_err       = @n_err                      OUTPUT,         
           @c_errmsg    = @c_errmsg                   OUTPUT        
                  
      IF EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PackinfoGenTrackingNo_SP AND TYPE = 'P')         
      BEGIN        
        DECLARE CUR_CTNTRACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
           SELECT DISTINCT I.Pickslipno, PKD.CartonNo      
           FROM INSERTED I       
           JOIN PACKDETAIL PKD (NOLOCK) ON I.Pickslipno = PKD.Pickslipno AND I.LabelNo = PKD.Labelno      
           LEFT JOIN PACKINFO PIF (NOLOCK) ON I.Pickslipno = PIF.Pickslipno AND PKD.CartonNo = PIF.CartonNo        
           WHERE (PIF.TrackingNo IS NULL       
           OR PIF.TrackingNo = '')      
           ORDER BY I.Pickslipno, PKD.CartonNo      
               
         OPEN CUR_CTNTRACK         
               
         FETCH NEXT FROM CUR_CTNTRACK INTO @c_Pickslipno, @n_Cartonno      
      
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)                 
         BEGIN                                                               
            SET @b_Success = 0        
                  
            EXECUTE isp_PackinfoGenTrackingNo_Wrapper       
                    @c_Pickslipno = @c_Pickslipno      
                  , @n_CartonNo  = @n_CartonNo      
                  , @c_PackinfoGenTrackingNo_SP = @c_PackinfoGenTrackingNo_SP        
                  , @b_Success = @b_Success     OUTPUT        
                  , @n_Err     = @n_err         OUTPUT         
                  , @c_ErrMsg  = @c_errmsg      OUTPUT        
                  
            IF @b_Success <> 1      
            BEGIN        
               SELECT @n_continue = 3        
            END        
                  
            FETCH NEXT FROM CUR_CTNTRACK INTO @c_Pickslipno, @n_Cartonno         
         END               
         CLOSE CUR_CTNTRACK      
         DEALLOCATE CUR_CTNTRACK      
      END                
   END                                                                                                                                                                                                                            
                                                                                                                                                                                                                            
   --NJOW04      
   IF @n_continue = 1 or @n_continue = 2        
   BEGIN      
      IF EXISTS(SELECT 1 FROM INSERTED WHERE CartonNo = 0) AND EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PackinfoGenTrackingNo_SP AND TYPE = 'P') --NJOW06      
      BEGIN      
         UPDATE PACKINFO WITH (ROWLOCK)      
         SET PACKINFO.Qty = PACKINFO.Qty + INSERTED.Qty      
         FROM INSERTED      
         CROSS APPLY (SELECT MAX(PKD.CartonNo) AS CartonNo FROM PACKDETAIL PKD (NOLOCK) WHERE PKD.Pickslipno = INSERTED.Pickslipno AND PKD.LabelNo = INSERTED.LabelNo) CTN      
         JOIN PACKINFO ON INSERTED.Pickslipno = PACKINFO.Pickslipno      
                       AND CTN.CartonNo = PACKINFO.CartonNo              
      
         IF (@c_DefaultPackInfo = '1') --(WL01 End)      
         BEGIN      
            UPDATE PACKINFO WITH (ROWLOCK)      
            SET PACKINFO.Weight = PACKINFO.Weight + (INSERTED.Qty * Sku.StdGrossWgt),      
                PACKINFO.Cube = PACKINFO.Cube + CASE WHEN ISNULL(CZ.Cube,0) = 0 THEN INSERTED.Qty * Sku.StdCube ELSE 0 END,      
                PACKINFO.CartonType = CASE WHEN ISNULL(PACKINFO.CartonType,'') = '' THEN ISNULL(CZ.CartonType,'') ELSE PACKINFO.CartonType END   --WL02      
            FROM INSERTED       
            CROSS APPLY (SELECT MAX(PKD.CartonNo) AS CartonNo FROM PACKDETAIL PKD (NOLOCK) WHERE PKD.Pickslipno = INSERTED.Pickslipno AND PKD.LabelNo = INSERTED.LabelNo) CTN                  
            JOIN PACKINFO ON INSERTED.Pickslipno = PACKINFO.Pickslipno      
                          AND CTN.CartonNo = PACKINFO.CartonNo                               
            JOIN STORERCONFIG (NOLOCK) ON INSERTED.StorerKey = STORERCONFIG.StorerKey           
                                        AND STORERCONFIG.ConfigKey = 'Default_PackInfo' AND STORERCONFIG.SValue='1'      
            JOIN STORER (NOLOCK) ON (INSERTED.StorerKey = STORER.StorerKey)      
            JOIN SKU (NOLOCK) ON (INSERTED.Storerkey = SKU.Storerkey AND INSERTED.SKU = SKU.Sku)      
            LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.CartonType = PACKINFO.CartonType)       
         END                                                    
      END      
      ELSE      
      BEGIN      
         UPDATE PACKINFO WITH (ROWLOCK)      
         SET PACKINFO.Qty = PACKINFO.Qty + INSERTED.Qty      
         FROM INSERTED      
         JOIN PACKINFO ON INSERTED.Pickslipno = PACKINFO.Pickslipno      
                       AND INSERTED.CartonNo = PACKINFO.CartonNo       
               
         --(WL01 Start)      
         --IF EXISTS(SELECT 1      
         --          FROM INSERTED      
         --          JOIN STORERCONFIG (NOLOCK) ON INSERTED.StorerKey = STORERCONFIG.StorerKey           
         --                                     AND STORERCONFIG.ConfigKey = 'Default_PackInfo' AND STORERCONFIG.SValue='1')      
         IF (@c_DefaultPackInfo = '1') --(WL01 End)      
         BEGIN      
            UPDATE PACKINFO WITH (ROWLOCK)      
            SET PACKINFO.Weight = PACKINFO.Weight + (INSERTED.Qty * Sku.StdGrossWgt),      
                PACKINFO.Cube = PACKINFO.Cube + CASE WHEN ISNULL(CZ.Cube,0) = 0 THEN INSERTED.Qty * Sku.StdCube ELSE 0 END,      
                PACKINFO.CartonType = CASE WHEN ISNULL(PACKINFO.CartonType,'') = '' THEN ISNULL(CZ.CartonType,'') ELSE PACKINFO.CartonType END   --WL02      
            FROM INSERTED       
            JOIN PACKINFO ON INSERTED.Pickslipno = PACKINFO.Pickslipno      
                          AND INSERTED.CartonNo = PACKINFO.CartonNo                               
            JOIN STORERCONFIG (NOLOCK) ON INSERTED.StorerKey = STORERCONFIG.StorerKey           
                                        AND STORERCONFIG.ConfigKey = 'Default_PackInfo' AND STORERCONFIG.SValue='1'      
            JOIN STORER (NOLOCK) ON (INSERTED.StorerKey = STORER.StorerKey)      
            JOIN SKU (NOLOCK) ON (INSERTED.Storerkey = SKU.Storerkey AND INSERTED.SKU = SKU.Sku)      
            LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.CartonType = PACKINFO.CartonType)       
         END      
      END      
      
      
      --(WL01 Start)      
      --IF EXISTS (SELECT 1       
      --           FROM INSERTED       
      --           JOIN STORERCONFIG SC (NOLOCK) ON INSERTED.Storerkey = SC.Storerkey AND SC.Configkey = 'PackCartonGID' AND SC.Svalue = '1')        
      IF (@c_PackCartonGID = '1')      
      BEGIN      
         DECLARE @dt_TimeIn DATETIME, @dt_TimeOut DATETIME      
         SET @dt_TimeIn = GETDATE()      
      
         SELECT @c_CartonGID = CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN      
                              CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(PACKDETAIL.LABELNO,CAST(CL.UDF02 AS INT)      
                             ,CAST(CL.UDF03 AS INT) - CAST(CL.UDF02 AS INT) + 1)      
                             ,CAST(CL.LONG AS INT) - LEN(CL.UDF01))      
                              WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN CL.UDF01 + PACKDETAIL.LABELNO ELSE PACKDETAIL.LABELNO END      
         FROM INSERTED      
         LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo      
   OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM      
                      CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = PackDetail.STORERKEY AND CL.CODE = 'SUPERHUB' AND      
                     (CL.CODE2 = @c_Facility OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL       
         WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
         AND   PACKDETAIL.LabelNo = INSERTED.LabelNo       
         AND   INSERTED.PickSlipNo LIKE 'P%'      
      
         --INSERT INTO TRACEINFO (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Col1, Col2, Col3)      
         --SELECT 'ntrPackDetailAdd', NULL, NULL, 'Pickslipno', 'CartonNo', 'CartonGID', INSERTED.Pickslipno, INSERTED.CartonNo, @c_CartonGID      
         --FROM INSERTED WITH (NOLOCK)        
         --LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo      
         --WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
         --AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
         --AND   INSERTED.PickSlipNo LIKE 'P%'      
      
         IF EXISTS (SELECT 1 FROM INSERTED WITH (NOLOCK) WHERE INSERTED.CartonNo = 0) --From RDT      
         BEGIN      
            SELECT @nCartonNo = MAX(PACKDETAIL.CartonNo)       
            FROM PACKDETAIL WITH (NOLOCK)        
            JOIN INSERTED WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo AND         
                                            PACKDETAIL.LabelNo = INSERTED.LabelNo)      
                                                    
            INSERT INTO PACKINFO (PickSlipNo, CartonNo, CartonType, [Cube], Qty, Weight, CartonGID)      
            SELECT DISTINCT INSERTED.PickSlipNo, @nCartonNo, NULL, 0, 0, 0, @c_CartonGID   --WL03      
            FROM INSERTED WITH (NOLOCK)        
            LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo      
            WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
            AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
          AND   @nCartonNo NOT IN (SELECT CartonNo FROM PACKINFO (NOLOCK) WHERE PickSlipNo = INSERTED.PickSlipNo)      
            AND   INSERTED.PickSlipNo LIKE 'P%'        
                  
            --SET @dt_TimeOut = GETDATE()      
                  
            --INSERT INTO TRACEINFO (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Col1, Col2, Col3)      
            --SELECT 'ntrPackDetailAdd', @dt_TimeIn, @dt_TimeOut, 'Pickslipno', 'CartonNo', 'CartonGID', INSERTED.Pickslipno, @nCartonNo, @c_CartonGID      
            --FROM INSERTED WITH (NOLOCK)        
            --LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo      
            --WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
            --AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
            --AND   INSERTED.PickSlipNo LIKE 'P%'      
            --END -- ELSE CARTONNO      
         END      
         ELSE --From EXCEED      
         BEGIN      
            INSERT INTO PACKINFO (PickSlipNo, CartonNo, CartonType, [Cube], Qty, Weight, CartonGID)      
            SELECT DISTINCT INSERTED.PickSlipNo, INSERTED.CartonNo, NULL, 0, INSERTED.Qty, 0, @c_CartonGID   --WL02   --WL03      
            FROM INSERTED WITH (NOLOCK)        
            LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo      
            WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
            AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
            AND   INSERTED.CartonNo NOT IN (SELECT CartonNo FROM PACKINFO (NOLOCK) WHERE PickSlipNo = INSERTED.PickSlipNo)      
            AND   INSERTED.PickSlipNo LIKE 'P%'        
                  
            --SET @dt_TimeOut = GETDATE()      
                  
            --INSERT INTO TRACEINFO (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Col1, Col2, Col3)      
            --SELECT 'ntrPackDetailAdd', @dt_TimeIn, @dt_TimeOut, 'Pickslipno', 'CartonNo', 'CartonGID', INSERTED.CartonNo, @nCartonNo, @c_CartonGID      
            --FROM INSERTED WITH (NOLOCK)        
            --LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo      
            --WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo        
            --AND   PACKDETAIL.LabelNo = INSERTED.LabelNo        
            --AND   INSERTED.PickSlipNo LIKE 'P%'      
         END      
               
      
      END--Packcartongid       
      --(WL01 END)      
   END      
         
/* #INCLUDE <TRCCA2.SQL> */        
   IF @n_continue=3  -- Error Occured - Process And Return        
   BEGIN      
      DECLARE @n_IsRDT INT        
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT        
           
      IF @n_IsRDT = 1        
      BEGIN        
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here        
         -- Instead we commit and raise an error back to parent, let the parent decide        
           
         -- Commit until the level we begin with        
         WHILE @@TRANCOUNT > @n_starttcnt        
            COMMIT TRAN        
           
         -- Raise error with severity = 10, instead of the default severity 16.         
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger        
         RAISERROR (@n_err, 10, 1) WITH SETERROR         
           
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten        
      END        
      ELSE        
      BEGIN        
         IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt        
         BEGIN        
            ROLLBACK TRAN        
         END        
         ELSE        
         BEGIN        
            WHILE @@TRANCOUNT > @n_starttcnt        
            BEGIN        
               COMMIT TRAN        
            END        
         END        
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPackDetailAdd'        
 --RAISERROR @n_err @c_errmsg        
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
             
         RETURN        
         END        
   END      
   ELSE        
   BEGIN        
     WHILE @@TRANCOUNT > @n_starttcnt        
      BEGIN        
        COMMIT TRAN        
      END      
      RETURN        
   END        
END 

GO